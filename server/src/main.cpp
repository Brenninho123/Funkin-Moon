#include <algorithm>
#include <atomic>
#include <csignal>
#include <ctime>
#include <filesystem>
#include <fstream>
#include <functional>
#include <iostream>
#include <map>
#include <memory>
#include <mutex>
#include <random>
#include <thread>
#include <unordered_map>
#include <vector>

#include "config.hpp"
#include "http_client.hpp"
#include "moderation.hpp"
#include "net.hpp"
#include "rooms.hpp"
#include "stats.hpp"
#include "util.hpp"

using json = nlohmann::json;

namespace moon
{
namespace
{
constexpr int ProtocolVersion = 2;
constexpr size_t MaxRelayBytes = 2048;
constexpr size_t MaxLineBytes = 65536;
constexpr size_t MaxOutputBytes = 1024 * 1024;
constexpr size_t MaxHttpBytes = 8192;
constexpr int64_t JoinTimeoutMs = 10000;
constexpr int64_t IdleTimeoutMs = 45000;
constexpr int64_t HttpTimeoutMs = 30000;
constexpr int64_t AuthTtlMs = 5 * 60 * 1000;
constexpr int MaxScoreViolations = 5;
constexpr size_t MaxAdminAttempts = 10;
constexpr double RateBurst = 120.0;
constexpr double RatePerSecond = 50.0;
constexpr const char* UserAgent = "MoonEngineServer (https://github.com/Brenninho123/Funkin-Moon, 1.0)";

std::atomic<bool> gRunning{true};
std::string gLogFile;

void onSignal(int)
{
  gRunning = false;
}

void log(const std::string& message)
{
  std::time_t now = std::time(nullptr);
  char stamp[32];
  std::strftime(stamp, sizeof(stamp), "%Y-%m-%d %H:%M:%S", std::localtime(&now));
  std::cout << "[" << stamp << "] " << message << std::endl;

  if (!gLogFile.empty())
  {
    std::ofstream file(gLogFile, std::ios::app);

    if (file.good()) file << "[" << stamp << "] " << message << '\n';
  }
}

std::string jsonString(const json& object, const char* key)
{
  if (!object.is_object()) return std::string();

  auto it = object.find(key);

  return it != object.end() && it->is_string() ? it->get<std::string>() : std::string();
}

std::string dumpJson(const json& value)
{
  return value.dump(-1, ' ', false, json::error_handler_t::replace);
}

int64_t jsonInt(const json& object, const char* key, int64_t fallback)
{
  if (!object.is_object()) return fallback;

  auto it = object.find(key);

  if (it == object.end()) return fallback;
  if (it->is_number_integer()) return it->get<int64_t>();
  if (it->is_number()) return static_cast<int64_t>(it->get<double>());

  return fallback;
}

double jsonDouble(const json& object, const char* key, double fallback)
{
  if (!object.is_object()) return fallback;

  auto it = object.find(key);

  return it != object.end() && it->is_number() ? it->get<double>() : fallback;
}

bool jsonBool(const json& object, const char* key, bool fallback)
{
  if (!object.is_object()) return fallback;

  auto it = object.find(key);

  return it != object.end() && it->is_boolean() ? it->get<bool>() : fallback;
}

struct Profile
{
  std::string id;
  std::string username;
  std::string avatarUrl;

  json toJson() const
  {
    return json{{"id", id}, {"username", username}, {"avatarUrl", avatarUrl}};
  }
};

struct Session
{
  Profile profile;
  int64_t expires = 0;
};

struct Player
{
  std::string id;
  std::string username;
  std::string platform = "Unknown";
  std::string activity = "Idle";
  int64_t lastSeen = 0;
  bool authenticated = false;
  std::string avatarUrl;

  json toJson() const
  {
    return json{{"id", id},
                {"username", username},
                {"platform", platform},
                {"activity", activity},
                {"lastSeen", lastSeen},
                {"authenticated", authenticated},
                {"avatarUrl", avatarUrl}};
  }
};

struct Client
{
  uint64_t serial = 0;
  net::Socket socket = net::InvalidSocket;
  std::string remote;
  std::string input;
  std::string output;
  int64_t connectedAt = 0;
  int64_t lastReceive = 0;
  int64_t lastRefill = 0;
  double tokens = RateBurst;
  bool joined = false;
  bool detached = false;
  bool closing = false;
  Player player;
  std::string discordId;
  std::string tokenHash;
  std::string pendingState;
  std::string roomId;
  std::string resumeKey;
  bool forceLeave = false;
  int64_t lastChat = 0;
};

struct PendingAuth
{
  uint64_t clientSerial = 0;
  int64_t expires = 0;
};

struct Metrics
{
  uint64_t connections = 0;
  uint64_t messages = 0;
  uint64_t joins = 0;
  uint64_t roomsCreated = 0;
  uint64_t roundsStarted = 0;
  uint64_t roundsFinished = 0;
  uint64_t reconnects = 0;
  uint64_t scoreViolations = 0;
  uint64_t rateLimited = 0;
  uint64_t bannedRefusals = 0;
  uint64_t httpRequests = 0;
};

struct HttpConn
{
  uint64_t serial = 0;
  net::Socket socket = net::InvalidSocket;
  std::string input;
  std::string output;
  int64_t createdAt = 0;
  bool waiting = false;
  bool closeWhenFlushed = false;
  bool closing = false;
  std::string remote;
};

struct AuthResult
{
  bool ok = false;
  Profile profile;
  std::string error;
};

std::string firstToken(const std::string& text, size_t& position)
{
  size_t start = position;

  while (position < text.size() && text[position] != ' ') position++;

  std::string token = text.substr(start, position - start);

  while (position < text.size() && text[position] == ' ') position++;

  return token;
}

std::string headerValue(const std::string& request, const std::string& name)
{
  std::string lowerRequest = request;
  std::string lowerName = name;

  std::transform(lowerRequest.begin(), lowerRequest.end(), lowerRequest.begin(), [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
  std::transform(lowerName.begin(), lowerName.end(), lowerName.begin(), [](unsigned char c) { return static_cast<char>(std::tolower(c)); });

  std::string needle = "\r\n" + lowerName + ":";
  size_t start = lowerRequest.find(needle);

  if (start == std::string::npos) return std::string();

  start += needle.size();

  size_t end = request.find("\r\n", start);

  if (end == std::string::npos) end = request.size();

  std::string value = request.substr(start, end - start);

  while (!value.empty() && (value.front() == ' ' || value.front() == '\t')) value.erase(value.begin());
  while (!value.empty() && (value.back() == ' ' || value.back() == '\t')) value.pop_back();

  return value;
}

bool sameSecret(const std::string& a, const std::string& b)
{
  unsigned char diff = static_cast<unsigned char>(a.size() != b.size());
  size_t length = std::min(a.size(), b.size());

  for (size_t i = 0; i < length; i++) diff |= static_cast<unsigned char>(a[i] ^ b[i]);

  return diff == 0;
}

std::map<std::string, std::string> parseQuery(const std::string& query)
{
  std::map<std::string, std::string> values;
  size_t start = 0;

  while (start <= query.size())
  {
    size_t end = query.find('&', start);

    if (end == std::string::npos) end = query.size();

    std::string pair = query.substr(start, end - start);
    size_t equals = pair.find('=');

    if (!pair.empty())
    {
      if (equals == std::string::npos) values[urlDecode(pair)] = "";
      else values[urlDecode(pair.substr(0, equals))] = urlDecode(pair.substr(equals + 1));
    }

    start = end + 1;
  }

  return values;
}

std::string resultPage(bool ok, const std::string& title, const std::string& message)
{
  std::string accent = ok ? "#3ddc97" : "#ff6b6b";

  return "<!doctype html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">"
         "<title>Moon Engine</title><style>body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;"
         "background:#101722;color:#e8eefc;font-family:system-ui,sans-serif}main{max-width:420px;padding:32px;text-align:center}"
         "h1{margin:0 0 12px;font-size:24px;color:" +
         accent + "}p{margin:0;line-height:1.5;color:#b7c8ff}</style></head><body><main><h1>" + htmlEscape(title) + "</h1><p>" +
         htmlEscape(message) + "</p></main></body></html>";
}

AuthResult exchangeDiscord(const DiscordConfig& config, const std::string& code)
{
  AuthResult result;

  std::string form = "client_id=" + urlEncode(config.clientId) + "&client_secret=" + urlEncode(config.clientSecret) +
                     "&grant_type=authorization_code&code=" + urlEncode(code) + "&redirect_uri=" + urlEncode(config.redirectUri);

  HttpResponse tokenResponse = httpRequest("POST", config.apiBase + "/oauth2/token",
                                           {{"Content-Type", "application/x-www-form-urlencoded"}, {"Accept", "application/json"}, {"User-Agent", UserAgent}}, form);

  if (!tokenResponse.ok())
  {
    result.error = "token_exchange_failed";
    log("discord token exchange failed: status " + std::to_string(tokenResponse.status) + " " + tokenResponse.error);
    return result;
  }

  json tokenJson = json::parse(tokenResponse.body, nullptr, false);
  std::string accessToken = jsonString(tokenJson, "access_token");

  if (accessToken.empty())
  {
    result.error = "token_exchange_failed";
    return result;
  }

  HttpResponse meResponse = httpRequest("GET", config.apiBase + "/users/@me",
                                        {{"Authorization", "Bearer " + accessToken}, {"Accept", "application/json"}, {"User-Agent", UserAgent}}, "");

  HttpResponse revokeResponse = httpRequest("POST", config.apiBase + "/oauth2/token/revoke",
                                            {{"Content-Type", "application/x-www-form-urlencoded"}, {"User-Agent", UserAgent}},
                                            "client_id=" + urlEncode(config.clientId) + "&client_secret=" + urlEncode(config.clientSecret) +
                                              "&token=" + urlEncode(accessToken));
  (void) revokeResponse;

  if (!meResponse.ok())
  {
    result.error = "profile_fetch_failed";
    log("discord profile fetch failed: status " + std::to_string(meResponse.status) + " " + meResponse.error);
    return result;
  }

  json me = json::parse(meResponse.body, nullptr, false);
  std::string id = jsonString(me, "id");

  if (id.empty() || id.find_first_not_of("0123456789") != std::string::npos)
  {
    result.error = "profile_fetch_failed";
    return result;
  }

  std::string name = jsonString(me, "global_name");

  if (name.empty()) name = jsonString(me, "username");

  name = sanitizeText(name, 32);

  if (name.empty()) name = "Discord User";

  std::string avatar = jsonString(me, "avatar");
  std::string avatarUrl;

  if (!avatar.empty() && avatar.find_first_not_of("0123456789abcdefABCDEF_") == std::string::npos)
  {
    avatarUrl = config.cdnBase + "/avatars/" + id + "/" + avatar + (avatar.rfind("a_", 0) == 0 ? ".gif" : ".png") + "?size=128";
  }
  else
  {
    unsigned long long numeric = 0;

    try
    {
      numeric = std::stoull(id);
    }
    catch (...)
    {
    }

    avatarUrl = config.cdnBase + "/embed/avatars/" + std::to_string((numeric >> 22) % 6) + ".png";
  }

  result.ok = true;
  result.profile.id = id;
  result.profile.username = name;
  result.profile.avatarUrl = avatarUrl;

  return result;
}

class Server
{
public:
  explicit Server(Config config) : config(std::move(config)), startedAt(nowMs()) {}

  int run()
  {
    std::string error;

    tcpListener = net::listenTcp(config.bindAddress, config.port, error);

    if (tcpListener == net::InvalidSocket)
    {
      log("fatal: " + error);
      return 1;
    }

    httpListener = net::listenTcp(config.bindAddress, config.httpPort, error);

    if (httpListener == net::InvalidSocket)
    {
      log("fatal: " + error);
      net::closeSocket(tcpListener);
      return 1;
    }

    std::filesystem::create_directories(config.dataDir);
    gLogFile = config.logFile;
    loadSessions();
    leaderboard.load(leaderboardPath());
    stats.load(statsPath());
    bans.load(bansPath());
    bans.purgeExpired(nowMs());

    log(config.serverName + " listening on " + config.bindAddress + ":" + std::to_string(config.port) + " (game) and :" + std::to_string(config.httpPort) + " (http)");
    log(config.discord.enabled() ? "discord login enabled, redirect uri " + config.discord.redirectUri : "discord login disabled (set MOON_DISCORD_CLIENT_ID and MOON_DISCORD_CLIENT_SECRET)");
    log(config.adminToken.empty() ? "admin api disabled (set MOON_ADMIN_TOKEN to at least 16 characters)" : "admin api enabled");
    log("loaded " + std::to_string(stats.size()) + " player stats and " + std::to_string(bans.size()) + " bans");

    int64_t lastTick = nowMs();

    while (gRunning)
    {
      std::vector<net::PollFd> fds;
      std::vector<std::pair<int, uint64_t>> owners;

      addPoll(fds, owners, tcpListener, POLLIN, 0, 0);
      addPoll(fds, owners, httpListener, POLLIN, 1, 0);

      for (auto& entry : clients)
      {
        Client& client = *entry.second;
        addPoll(fds, owners, client.socket, POLLIN | (client.output.empty() ? 0 : POLLOUT), 2, client.serial);
      }

      for (auto& entry : httpConns)
      {
        HttpConn& conn = *entry.second;
        addPoll(fds, owners, conn.socket, (conn.waiting ? 0 : POLLIN) | (conn.output.empty() ? 0 : POLLOUT), 3, conn.serial);
      }

      int ready = net::pollSockets(fds, 100);

      if (ready > 0)
      {
        for (size_t i = 0; i < fds.size(); i++)
        {
          if (fds[i].revents == 0) continue;

          handleEvent(owners[i].first, owners[i].second, fds[i].revents);
        }
      }

      runCompletedJobs();

      int64_t now = nowMs();

      if (now - lastTick >= 1000)
      {
        lastTick = now;
        tick(now);
      }

      reap();
    }

    log("shutting down");

    announceShutdown();
    saveAll();

    for (auto& entry : clients) net::closeSocket(entry.second->socket);
    for (auto& entry : httpConns) net::closeSocket(entry.second->socket);

    net::closeSocket(tcpListener);
    net::closeSocket(httpListener);

    while (activeJobs > 0) std::this_thread::sleep_for(std::chrono::milliseconds(20));

    return 0;
  }

private:
  Config config;
  int64_t startedAt;
  net::Socket tcpListener = net::InvalidSocket;
  net::Socket httpListener = net::InvalidSocket;
  uint64_t nextSerial = 1;
  uint64_t nextPlayer = 1;
  std::map<uint64_t, std::unique_ptr<Client>> clients;
  std::map<uint64_t, std::unique_ptr<HttpConn>> httpConns;
  std::unordered_map<std::string, uint64_t> discordClients;
  std::unordered_map<std::string, PendingAuth> pendingAuth;
  std::unordered_map<std::string, Session> sessions;
  std::mutex jobMutex;
  std::vector<std::function<void()>> completedJobs;
  std::atomic<int> activeJobs{0};
  std::map<std::string, Room> rooms;
  Leaderboard leaderboard;
  StatsBook stats;
  BanList bans;
  Metrics metrics;
  std::map<std::string, size_t> adminFailures;
  int64_t lastScoreSave = 0;
  int64_t lastAdminReset = 0;
  std::mt19937 rng{std::random_device{}()};

  static void addPoll(std::vector<net::PollFd>& fds, std::vector<std::pair<int, uint64_t>>& owners, net::Socket socket, int events, int kind,
                      uint64_t serial)
  {
    net::PollFd fd{};
    fd.fd = socket;
    fd.events = static_cast<short>(events);
    fds.push_back(fd);
    owners.emplace_back(kind, serial);
  }

  Client* findClient(uint64_t serial)
  {
    auto it = clients.find(serial);

    return it == clients.end() ? nullptr : it->second.get();
  }

  HttpConn* findHttp(uint64_t serial)
  {
    auto it = httpConns.find(serial);

    return it == httpConns.end() ? nullptr : it->second.get();
  }

  size_t joinedCount() const
  {
    size_t count = 0;

    for (const auto& entry : clients)
    {
      if (entry.second->joined && !entry.second->detached) count++;
    }

    return count;
  }

  void handleEvent(int kind, uint64_t serial, int events)
  {
    if (kind == 0)
    {
      acceptGameClients();
    }
    else if (kind == 1)
    {
      acceptHttpClients();
    }
    else if (kind == 2)
    {
      Client* client = findClient(serial);

      if (client == nullptr || client->closing) return;

      if (events & (POLLIN | POLLHUP | POLLERR)) readClient(*client);
      if (!client->closing && (events & POLLOUT)) flushClient(*client);
    }
    else
    {
      HttpConn* conn = findHttp(serial);

      if (conn == nullptr || conn->closing) return;

      if (events & (POLLIN | POLLHUP | POLLERR)) readHttp(*conn);
      if (!conn->closing && (events & POLLOUT)) flushHttp(*conn);
    }
  }

  void acceptGameClients()
  {
    for (;;)
    {
      std::string remote;
      net::Socket socket = net::acceptClient(tcpListener, remote);

      if (socket == net::InvalidSocket) return;

      size_t sameAddress = 0;

      for (const auto& entry : clients)
      {
        if (entry.second->remote == remote && !entry.second->closing) sameAddress++;
      }

      if (sameAddress >= config.maxPerIp || clients.size() >= config.maxPlayers * 2)
      {
        net::closeSocket(socket);
        continue;
      }

      auto client = std::make_unique<Client>();
      client->serial = nextSerial++;
      client->socket = socket;
      client->remote = remote;
      client->connectedAt = nowMs();
      client->lastReceive = client->connectedAt;
      client->lastRefill = client->connectedAt;
      clients[client->serial] = std::move(client);
      metrics.connections++;
    }
  }

  void acceptHttpClients()
  {
    for (;;)
    {
      std::string remote;
      net::Socket socket = net::acceptClient(httpListener, remote);

      if (socket == net::InvalidSocket) return;

      if (httpConns.size() >= 256)
      {
        net::closeSocket(socket);
        continue;
      }

      auto conn = std::make_unique<HttpConn>();
      conn->serial = nextSerial++;
      conn->socket = socket;
      conn->createdAt = nowMs();
      conn->remote = remote;
      httpConns[conn->serial] = std::move(conn);
    }
  }

  void closeClient(Client& client, const std::string& reason)
  {
    if (client.closing) return;

    client.closing = true;

    log("client " + std::to_string(client.serial) + " (" + client.remote + ") closed: " + reason);

    detach(client);
  }

  void detach(Client& client)
  {
    if (client.detached) return;

    client.detached = true;

    if (!client.roomId.empty() && client.joined && !client.forceLeave && config.reconnectGraceSeconds > 0) markAway(client);
    else leaveRoom(client, "disconnected");

    if (!client.pendingState.empty()) pendingAuth.erase(client.pendingState);

    if (!client.discordId.empty())
    {
      auto it = discordClients.find(client.discordId);

      if (it != discordClients.end() && it->second == client.serial) discordClients.erase(it);
    }

    if (client.joined)
    {
      log("player left: " + client.player.username + " (" + client.player.id + "), " + std::to_string(joinedCount()) + " online");
      broadcast("userLeft", json{{"id", client.player.id}}, client.serial);
    }
  }

  void reap()
  {
    for (auto it = clients.begin(); it != clients.end();)
    {
      Client& client = *it->second;

      if (client.closing && (client.output.empty() || client.detached))
      {
        detach(client);
        net::closeSocket(client.socket);
        it = clients.erase(it);
      }
      else
      {
        ++it;
      }
    }

    for (auto it = httpConns.begin(); it != httpConns.end();)
    {
      if (it->second->closing)
      {
        net::closeSocket(it->second->socket);
        it = httpConns.erase(it);
      }
      else
      {
        ++it;
      }
    }
  }

  void readClient(Client& client)
  {
    char buffer[4096];

    for (;;)
    {
      int received = net::receiveSome(client.socket, buffer, sizeof(buffer));

      if (received > 0)
      {
        client.lastReceive = nowMs();
        client.input.append(buffer, static_cast<size_t>(received));

        if (!extractLines(client)) return;

        continue;
      }

      if (received == 0)
      {
        closeClient(client, "disconnected");
        return;
      }

      if (!net::wouldBlock()) closeClient(client, "socket error");

      return;
    }
  }

  bool extractLines(Client& client)
  {
    size_t newline = client.input.find('\n');

    while (newline != std::string::npos)
    {
      std::string line = client.input.substr(0, newline);
      client.input.erase(0, newline + 1);

      if (!line.empty() && line.back() == '\r') line.pop_back();

      if (!line.empty())
      {
        if (!takeToken(client))
        {
          metrics.rateLimited++;
          client.forceLeave = true;
          sendError(client, "rate_limited");
          closeClient(client, "rate limited");
          return false;
        }

        handleLine(client, line);

        if (client.closing) return false;
      }

      newline = client.input.find('\n');
    }

    if (client.input.size() > MaxLineBytes)
    {
      sendError(client, "message_too_large");
      closeClient(client, "message too large");
      return false;
    }

    return true;
  }

  bool takeToken(Client& client)
  {
    int64_t now = nowMs();
    double elapsed = static_cast<double>(now - client.lastRefill) / 1000.0;

    client.lastRefill = now;
    client.tokens = std::min(RateBurst, client.tokens + elapsed * RatePerSecond);

    if (client.tokens < 1.0) return false;

    client.tokens -= 1.0;

    return true;
  }

  void sendRaw(Client& client, const std::string& line)
  {
    if (client.closing) return;

    client.output += line;

    if (client.output.size() > MaxOutputBytes)
    {
      client.output.clear();
      closeClient(client, "output buffer overflow");
      return;
    }

    flushClient(client);
  }

  void send(Client& client, const std::string& type, const json& data)
  {
    sendRaw(client, dumpJson(json{{"type", type}, {"data", data}}) + "\n");
  }

  void sendError(Client& client, const std::string& reason)
  {
    send(client, "error", json{{"reason", reason}});
  }

  void flushClient(Client& client)
  {
    while (!client.output.empty())
    {
      int sent = net::sendSome(client.socket, client.output.data(), client.output.size());

      if (sent > 0)
      {
        client.output.erase(0, static_cast<size_t>(sent));
        continue;
      }

      if (sent < 0 && net::wouldBlock()) return;

      client.output.clear();
      client.closing = true;
      detach(client);
      return;
    }
  }

  void broadcast(const std::string& type, const json& data, uint64_t exceptSerial)
  {
    std::string line = dumpJson(json{{"type", type}, {"data", data}}) + "\n";

    for (auto& entry : clients)
    {
      Client& other = *entry.second;

      if (!other.joined || other.closing || other.serial == exceptSerial) continue;

      sendRaw(other, line);
    }
  }

  json playersJson()
  {
    json list = json::array();

    for (auto& entry : clients)
    {
      const Client& client = *entry.second;

      if (client.joined && !client.closing) list.push_back(client.player.toJson());
    }

    return list;
  }

  void handleLine(Client& client, const std::string& line)
  {
    json message = json::parse(line, nullptr, false);

    if (message.is_discarded() || !message.is_object()) return;

    metrics.messages++;

    std::string type = jsonString(message, "type");
    json data = message.contains("data") && message["data"].is_object() ? message["data"] : json::object();

    if (type == "ping")
    {
      send(client, "pong", json::object());
    }
    else if (type == "join")
    {
      handleJoin(client, data);
    }
    else if (!client.joined)
    {
      sendError(client, "not_joined");
    }
    else if (type == "presence")
    {
      client.player.lastSeen = nowMs();
    }
    else if (type == "activity")
    {
      handleActivity(client, data);
    }
    else if (type == "list")
    {
      send(client, "activeUsers", json{{"users", playersJson()}});
    }
    else if (type == "songResult")
    {
      handleSongResult(client, data);
    }
    else if (type == "leaderboard")
    {
      handleLeaderboard(client, data);
    }
    else if (type == "stats")
    {
      handleStats(client, data);
    }
    else if (type.rfind("mp_", 0) == 0)
    {
      if (!handleRoomMessage(client, type, data)) sendError(client, "unknown_message");
    }
    else if (type == "auth_begin")
    {
      handleAuthBegin(client);
    }
    else if (type == "auth_resume")
    {
      handleAuthResume(client, jsonString(data, "token"));
    }
    else if (type == "auth_logout")
    {
      handleAuthLogout(client);
    }
  }

  Room* findRoom(const std::string& id)
  {
    auto it = rooms.find(id);

    return it == rooms.end() ? nullptr : &it->second;
  }

  Room* roomOf(Client& client)
  {
    return client.roomId.empty() ? nullptr : findRoom(client.roomId);
  }

  std::string roomHostId(const Room& room) const
  {
    const RoomMember* host = findMember(room, room.hostSerial);

    return host != nullptr ? host->id : std::string();
  }

  json memberJson(const Room& room, const RoomMember& member) const
  {
    return json{{"id", member.id},
                {"username", member.username},
                {"avatarUrl", member.avatarUrl},
                {"ready", member.ready},
                {"finished", member.finished},
                {"score", member.score},
                {"combo", member.combo},
                {"accuracy", member.accuracy},
                {"isHost", member.serial != 0 && member.serial == room.hostSerial},
                {"away", member.away}};
  }

  json roomJson(const Room& room) const
  {
    json players = json::array();
    json members = json::array();

    for (const auto& member : room.members)
    {
      players.push_back(member.id);
      members.push_back(memberJson(room, member));
    }

    json result = {{"roomId", room.id},
                   {"name", room.name},
                   {"hostId", roomHostId(room)},
                   {"isPublic", room.isPublic},
                   {"maxPlayers", room.maxPlayers},
                   {"state", room.state},
                   {"players", players},
                   {"members", members},
                   {"round", room.round}};

    result["songId"] = room.songId.empty() ? json(nullptr) : json(room.songId);
    result["difficultyId"] = room.songId.empty() ? json(nullptr) : json(room.difficultyId);
    result["variation"] = room.songId.empty() ? json(nullptr) : json(room.variation);

    return result;
  }

  json roomSummary(const Room& room) const
  {
    const RoomMember* host = findMember(room, room.hostSerial);

    return json{{"roomId", room.id},
                {"name", room.name},
                {"hostName", host != nullptr ? host->username : std::string()},
                {"players", room.members.size()},
                {"maxPlayers", room.maxPlayers},
                {"state", room.state},
                {"songId", room.songId},
                {"difficultyId", room.difficultyId}};
  }

  json publicRoomsJson()
  {
    json list = json::array();

    for (const auto& entry : rooms)
    {
      if (entry.second.isPublic) list.push_back(roomSummary(entry.second));
    }

    return list;
  }

  void sendToRoom(const Room& room, const std::string& type, const json& data, uint64_t exceptSerial = 0)
  {
    std::string line = dumpJson(json{{"type", type}, {"data", data}}) + "\n";
    std::vector<uint64_t> serials;

    for (const auto& member : room.members)
    {
      if (member.serial != exceptSerial) serials.push_back(member.serial);
    }

    for (uint64_t serial : serials)
    {
      Client* target = findClient(serial);

      if (target != nullptr && !target->closing) sendRaw(*target, line);
    }
  }

  RoomMember makeMember(Client& client) const
  {
    RoomMember member;
    member.serial = client.serial;
    member.id = client.player.id;
    member.username = client.player.username;
    member.avatarUrl = client.player.avatarUrl;
    member.joinedAt = nowMs();
    member.authenticated = client.player.authenticated;

    return member;
  }

  std::string uniqueRoomCode()
  {
    for (int attempt = 0; attempt < 64; attempt++)
    {
      std::string code = makeRoomCode([this]() { return static_cast<uint32_t>(rng()); });

      if (rooms.find(code) == rooms.end()) return code;
    }

    return std::string();
  }

  void roomFailure(Client& client, const std::string& reason)
  {
    send(client, "mp_roomJoinFailed", json{{"reason", reason}});
  }

  void handleCreateRoom(Client& client, const json& data)
  {
    if (!client.roomId.empty())
    {
      roomFailure(client, "already_in_room");
      return;
    }

    if (rooms.size() >= config.maxRooms)
    {
      sendError(client, "room_limit");
      return;
    }

    std::string code = uniqueRoomCode();

    if (code.empty())
    {
      sendError(client, "room_limit");
      return;
    }

    Room room;
    room.id = code;
    room.name = sanitizeText(jsonString(data, "name"), 32);

    if (room.name.empty()) room.name = client.player.username + "'s room";

    room.isPublic = jsonBool(data, "isPublic", true);
    room.maxPlayers = static_cast<size_t>(clampInt(jsonInt(data, "maxPlayers", 4), 2, static_cast<int64_t>(config.maxRoomPlayers)));
    room.createdAt = nowMs();
    room.hostSerial = client.serial;
    room.members.push_back(makeMember(client));

    rooms[code] = room;
    client.roomId = code;
    metrics.roomsCreated++;

    log("room " + code + " created by " + client.player.username + " (" + std::to_string(rooms.size()) + " rooms)");

    send(client, "mp_roomCreated", roomJson(rooms[code]));
  }

  void handleJoinRoom(Client& client, const json& data)
  {
    if (!client.roomId.empty())
    {
      roomFailure(client, "already_in_room");
      return;
    }

    Room* room = findRoom(normalizeRoomCode(jsonString(data, "roomId")));

    if (room == nullptr)
    {
      roomFailure(client, "not_found");
      return;
    }

    if (room->members.size() >= room->maxPlayers)
    {
      roomFailure(client, "full");
      return;
    }

    if (room->state != "lobby")
    {
      roomFailure(client, "in_progress");
      return;
    }

    RoomMember member = makeMember(client);

    room->members.push_back(member);
    client.roomId = room->id;

    log(client.player.username + " joined room " + room->id + " (" + std::to_string(room->members.size()) + "/" + std::to_string(room->maxPlayers) + ")");

    std::string roomId = room->id;

    send(client, "mp_roomJoined", roomJson(*room));

    room = findRoom(roomId);

    if (room != nullptr) sendToRoom(*room, "mp_playerJoined", json{{"userId", member.id}, {"member", memberJson(*room, member)}}, client.serial);
  }

  void leaveRoom(Client& client, const std::string& reason)
  {
    if (client.roomId.empty()) return;

    std::string roomId = client.roomId;
    client.roomId.clear();

    Room* room = findRoom(roomId);

    if (room == nullptr) return;

    const RoomMember* leaving = findMember(*room, client.serial);
    std::string leavingId = leaving != nullptr ? leaving->id : client.player.id;
    bool wasHost = room->hostSerial == client.serial;

    removeMember(*room, client.serial);

    finishRemoval(roomId, leavingId, wasHost, reason);
  }

  void finishRemoval(const std::string& roomId, const std::string& leavingId, bool wasHost, const std::string& reason)
  {
    Room* room = findRoom(roomId);

    if (room == nullptr) return;

    if (room->members.empty())
    {
      rooms.erase(roomId);
      log("room " + roomId + " closed (" + std::to_string(rooms.size()) + " rooms)");
      return;
    }

    bool hostChanged = false;

    if (wasHost || room->hostSerial == 0)
    {
      uint64_t next = firstConnectedSerial(*room);
      hostChanged = next != room->hostSerial;
      room->hostSerial = next;
    }

    sendToRoom(*room, "mp_playerLeft", json{{"userId", leavingId}, {"reason", reason}, {"hostId", roomHostId(*room)}});

    room = findRoom(roomId);

    if (room == nullptr) return;

    if (hostChanged && room->hostSerial != 0) sendToRoom(*room, "mp_hostChanged", json{{"hostId", roomHostId(*room)}});

    room = findRoom(roomId);

    if (room != nullptr && room->state == "playing") evaluateRound(roomId, false);
  }

  void markAway(Client& client)
  {
    std::string roomId = client.roomId;
    client.roomId.clear();

    Room* room = findRoom(roomId);

    if (room == nullptr) return;

    RoomMember* member = findMember(*room, client.serial);

    if (member == nullptr) return;

    bool wasHost = room->hostSerial == client.serial;

    member->away = true;
    member->awayUntil = nowMs() + static_cast<int64_t>(config.reconnectGraceSeconds) * 1000;
    member->resumeKey = client.resumeKey;
    member->serial = 0;
    member->ready = member->ready && room->state == "lobby";

    std::string memberId = member->id;
    bool hostChanged = false;

    if (wasHost)
    {
      room->hostSerial = firstConnectedSerial(*room);
      hostChanged = room->hostSerial != 0;
    }

    log(client.player.username + " lost connection in room " + roomId + ", holding the place for " + std::to_string(config.reconnectGraceSeconds) + "s");

    sendToRoom(*room, "mp_playerAway", json{{"userId", memberId}, {"graceSeconds", config.reconnectGraceSeconds}, {"hostId", roomHostId(*room)}});

    room = findRoom(roomId);

    if (room != nullptr && hostChanged) sendToRoom(*room, "mp_hostChanged", json{{"hostId", roomHostId(*room)}});
  }

  void dropAwayMember(const std::string& roomId, const std::string& memberId)
  {
    Room* room = findRoom(roomId);

    if (room == nullptr || findAwayMemberById(*room, memberId) == nullptr) return;

    removeMemberById(*room, memberId);

    log(memberId + " did not come back to room " + roomId);

    finishRemoval(roomId, memberId, false, "timeout");
  }

  void expireAwayMembers(int64_t now)
  {
    std::vector<std::pair<std::string, std::string>> expired;

    for (const auto& entry : rooms)
    {
      for (const auto& member : entry.second.members)
      {
        if (member.away && member.awayUntil <= now) expired.emplace_back(entry.first, member.id);
      }
    }

    for (const auto& item : expired) dropAwayMember(item.first, item.second);
  }

  bool resumeRoom(Client& client, const std::string& key, RoomMember*& memberOut, Room*& roomOut)
  {
    if (!key.empty())
    {
      for (auto& entry : clients)
      {
        Client& other = *entry.second;

        if (other.serial != client.serial && !other.detached && !other.closing && other.resumeKey == key) closeClient(other, "replaced by a reconnect");
      }
    }

    for (auto& entry : rooms)
    {
      RoomMember* member = findMemberByResumeKey(entry.second, key);

      if (member == nullptr && client.player.authenticated) member = findAwayMemberById(entry.second, client.player.id);

      if (member != nullptr)
      {
        memberOut = member;
        roomOut = &entry.second;

        return true;
      }
    }

    return false;
  }

  void handleSelectSong(Client& client, const json& data)
  {
    Room* room = roomOf(client);

    if (room == nullptr)
    {
      sendError(client, "not_in_room");
      return;
    }

    if (room->hostSerial != client.serial)
    {
      sendError(client, "not_host");
      return;
    }

    if (room->state != "lobby")
    {
      sendError(client, "in_progress");
      return;
    }

    std::string songId = jsonString(data, "songId");
    std::string difficulty = jsonString(data, "difficultyId");
    std::string variation = jsonString(data, "variation");

    if (difficulty.empty()) difficulty = "normal";
    if (variation.empty()) variation = "default";

    if (!validIdentifier(songId) || !validIdentifier(difficulty) || !validIdentifier(variation))
    {
      sendError(client, "invalid_song");
      return;
    }

    room->songId = songId;
    room->difficultyId = difficulty;
    room->variation = variation;

    for (auto& member : room->members) member.ready = false;

    sendToRoom(*room, "mp_songSelected", json{{"songId", songId}, {"difficultyId", difficulty}, {"variation", variation}});
  }

  void handleSetReady(Client& client, const json& data)
  {
    Room* room = roomOf(client);

    if (room == nullptr)
    {
      sendError(client, "not_in_room");
      return;
    }

    RoomMember* member = findMember(*room, client.serial);

    if (member == nullptr || room->state != "lobby") return;

    member->ready = jsonBool(data, "ready", true);

    sendToRoom(*room, "mp_playerReady", json{{"userId", member->id}, {"ready", member->ready}});
  }

  void handleStartSong(Client& client)
  {
    Room* room = roomOf(client);

    if (room == nullptr)
    {
      sendError(client, "not_in_room");
      return;
    }

    if (room->hostSerial != client.serial)
    {
      sendError(client, "not_host");
      return;
    }

    if (room->state != "lobby")
    {
      sendError(client, "in_progress");
      return;
    }

    if (room->songId.empty())
    {
      sendError(client, "no_song");
      return;
    }

    if (room->members.size() < config.minPlayersToStart)
    {
      sendError(client, "not_enough_players");
      return;
    }

    if (!everyoneReady(*room))
    {
      sendError(client, "not_all_ready");
      return;
    }

    room->state = "playing";
    room->startedAt = nowMs();
    room->firstFinishAt = 0;
    room->seed = static_cast<int64_t>(rng() & 0x7fffffff);
    room->round++;
    metrics.roundsStarted++;

    json players = json::array();

    for (auto& member : room->members)
    {
      member.finished = false;
      member.score = 0;
      member.combo = 0;
      member.health = 0.5;
      member.accuracy = 0.0;
      players.push_back(member.id);
    }

    log("room " + room->id + " started " + room->songId + " (" + room->difficultyId + ") with " + std::to_string(room->members.size()) + " players");

    sendToRoom(*room, "mp_startSong",
               json{{"songId", room->songId},
                    {"difficultyId", room->difficultyId},
                    {"variation", room->variation},
                    {"seed", room->seed},
                    {"round", room->round},
                    {"players", players}});
  }

  void readScore(Client& client, Room& room, RoomMember& member, const json& data)
  {
    int64_t ceiling = scoreCeiling(nowMs() - room.startedAt, config.maxScorePerSecond, config.scoreBurst);
    int64_t reported = clampInt(jsonInt(data, "score", member.score), -2000000000, 2000000000);

    if (reported > ceiling)
    {
      reported = std::max<int64_t>(std::min(member.score, ceiling), 0);
      metrics.scoreViolations++;
      member.violations++;

      log("score out of range from " + member.username + " in room " + room.id + " (" + std::to_string(member.violations) + "/" + std::to_string(MaxScoreViolations) + ")");

      if (member.violations >= MaxScoreViolations)
      {
        client.forceLeave = true;
        send(client, "mp_roomClosed", json{{"reason", "cheating"}});
        leaveRoom(client, "removed");
        return;
      }
    }

    member.score = reported;
    member.combo = clampInt(jsonInt(data, "combo", member.combo), 0, 1000000);
    member.health = clampDouble(jsonDouble(data, "health", member.health), 0.0, 2.0);
    member.accuracy = clampDouble(jsonDouble(data, "accuracy", member.accuracy), 0.0, 100.0);
  }

  json scoreJson(const RoomMember& member) const
  {
    return json{{"userId", member.id},
                {"username", member.username},
                {"score", member.score},
                {"combo", member.combo},
                {"health", member.health},
                {"accuracy", member.accuracy}};
  }

  void handleScoreUpdate(Client& client, const json& data)
  {
    Room* room = roomOf(client);

    if (room == nullptr || room->state != "playing") return;

    RoomMember* member = findMember(*room, client.serial);

    if (member == nullptr || member->finished) return;

    readScore(client, *room, *member, data);

    room = roomOf(client);

    if (room == nullptr) return;

    member = findMember(*room, client.serial);

    if (member == nullptr) return;

    sendToRoom(*room, "mp_scoreUpdate", scoreJson(*member), client.serial);
  }

  void handleRelay(Client& client, const json& data)
  {
    Room* room = roomOf(client);

    if (room == nullptr || room->state != "playing") return;

    RoomMember* member = findMember(*room, client.serial);

    if (member == nullptr || member->finished) return;

    auto payload = data.find("payload");

    if (payload == data.end() || !payload->is_object()) return;

    std::string text = dumpJson(*payload);

    if (text.size() > MaxRelayBytes) return;

    sendToRoom(*room, "mp_relay", json{{"userId", member->id}, {"payload", *payload}}, client.serial);
  }

  void handlePlayerFinished(Client& client, const json& data)
  {
    Room* room = roomOf(client);

    if (room == nullptr || room->state != "playing") return;

    RoomMember* member = findMember(*room, client.serial);

    if (member == nullptr || member->finished) return;

    readScore(client, *room, *member, data);

    room = roomOf(client);

    if (room == nullptr) return;

    member = findMember(*room, client.serial);

    if (member == nullptr) return;

    member->finished = true;

    if (room->firstFinishAt == 0) room->firstFinishAt = nowMs();

    recordScore(client, room->songId, room->difficultyId, member->score);

    std::string roomId = room->id;
    json payload = scoreJson(*member);

    sendToRoom(*room, "mp_playerFinished", payload, client.serial);

    evaluateRound(roomId, false);
  }

  void evaluateRound(const std::string& roomId, bool force)
  {
    Room* room = findRoom(roomId);

    if (room == nullptr || room->state != "playing") return;

    if (force || everyoneFinished(*room)) finishRound(roomId);
  }

  void finishRound(const std::string& roomId)
  {
    Room* room = findRoom(roomId);

    if (room == nullptr || room->state != "playing") return;

    json rankings = json::array();

    for (const auto& ranked : rankMembers(room->members))
    {
      json entry = scoreJson(ranked.member);
      entry["rank"] = ranked.rank;
      entry["finished"] = ranked.member.finished;
      rankings.push_back(entry);
    }

    json results = {{"songId", room->songId}, {"difficultyId", room->difficultyId}, {"variation", room->variation}, {"round", room->round}, {"rankings", rankings}};

    bool contested = room->members.size() >= 2;
    int64_t now = nowMs();

    for (const auto& ranked : rankMembers(room->members))
    {
      const RoomMember& member = ranked.member;

      stats.recordRound(StatsBook::keyFor(member.authenticated, member.id, member.username), member.username, contested && member.finished && ranked.rank == 1, now);
    }

    room->state = "lobby";
    room->startedAt = 0;
    room->firstFinishAt = 0;
    room->lastResults = results;
    metrics.roundsFinished++;

    for (auto& member : room->members)
    {
      member.ready = false;
      member.finished = false;
      member.missedResults = member.away;
    }

    log("room " + roomId + " finished " + room->songId);

    sendToRoom(*room, "mp_results", results);

    room = findRoom(roomId);

    if (room != nullptr) sendToRoom(*room, "mp_roomState", roomJson(*room));
  }

  void handleChat(Client& client, const json& data)
  {
    std::string text = sanitizeText(jsonString(data, "text"), 200);

    if (text.empty()) return;

    int64_t now = nowMs();

    if (now - client.lastChat < config.chatCooldownMs)
    {
      sendError(client, "chat_cooldown");
      return;
    }

    client.lastChat = now;

    json message = {{"userId", client.player.id}, {"username", client.player.username}, {"text", text}, {"time", now}};

    Room* room = roomOf(client);

    if (jsonString(data, "scope") != "global" && room != nullptr)
    {
      message["scope"] = "room";
      sendToRoom(*room, "mp_chat", message);
    }
    else
    {
      message["scope"] = "global";
      broadcast("mp_chat", message, 0);
    }
  }

  void handleKick(Client& client, const json& data)
  {
    Room* room = roomOf(client);

    if (room == nullptr)
    {
      sendError(client, "not_in_room");
      return;
    }

    if (room->hostSerial != client.serial)
    {
      sendError(client, "not_host");
      return;
    }

    std::string target = jsonString(data, "userId");
    uint64_t targetSerial = 0;

    for (const auto& member : room->members)
    {
      if (member.id == target && member.serial != client.serial) targetSerial = member.serial;
    }

    if (targetSerial == 0)
    {
      sendError(client, "unknown_member");
      return;
    }

    Client* victim = findClient(targetSerial);

    if (victim == nullptr) return;

    send(*victim, "mp_roomClosed", json{{"reason", "kicked"}});
    leaveRoom(*victim, "kicked");
  }

  void handleRoomSettings(Client& client, const json& data)
  {
    Room* room = roomOf(client);

    if (room == nullptr || room->hostSerial != client.serial)
    {
      sendError(client, room == nullptr ? "not_in_room" : "not_host");
      return;
    }

    if (room->state != "lobby")
    {
      sendError(client, "in_progress");
      return;
    }

    std::string name = sanitizeText(jsonString(data, "name"), 32);

    if (!name.empty()) room->name = name;

    room->isPublic = jsonBool(data, "isPublic", room->isPublic);

    size_t wanted = static_cast<size_t>(clampInt(jsonInt(data, "maxPlayers", static_cast<int64_t>(room->maxPlayers)), 2, static_cast<int64_t>(config.maxRoomPlayers)));

    room->maxPlayers = std::max(wanted, room->members.size());

    sendToRoom(*room, "mp_roomState", roomJson(*room));
  }

  void handleQuickMatch(Client& client)
  {
    if (!client.roomId.empty())
    {
      roomFailure(client, "already_in_room");
      return;
    }

    Room* best = nullptr;

    for (auto& entry : rooms)
    {
      Room& candidate = entry.second;

      if (!candidate.isPublic || candidate.state != "lobby" || candidate.members.size() >= candidate.maxPlayers) continue;
      if (firstConnectedSerial(candidate) == 0) continue;

      if (best == nullptr || candidate.members.size() > best->members.size()) best = &candidate;
    }

    if (best != nullptr)
    {
      handleJoinRoom(client, json{{"roomId", best->id}});
      return;
    }

    handleCreateRoom(client, json{{"isPublic", true}, {"maxPlayers", 4}, {"name", client.player.username + "'s match"}});
  }

  std::string statsKeyFor(const std::string& id)
  {
    if (id.empty()) return std::string();

    for (const auto& entry : clients)
    {
      const Client& other = *entry.second;

      if (other.joined && !other.closing && other.player.id == id) return StatsBook::keyFor(other.player.authenticated, other.player.id, other.player.username);
    }

    return id;
  }

  json statsJson(const std::string& key, const std::string& shownId)
  {
    const PlayerStats* found = stats.find(key);
    PlayerStats empty;
    json result = (found != nullptr ? *found : empty).toJson(shownId);

    result["found"] = found != nullptr;

    return result;
  }

  void handleStats(Client& client, const json& data)
  {
    std::string wanted = sanitizeText(jsonString(data, "userId"), 80);
    std::string key = wanted.empty() ? StatsBook::keyFor(client.player.authenticated, client.player.id, client.player.username) : statsKeyFor(wanted);
    json result = statsJson(key, wanted.empty() ? client.player.id : wanted);

    if (wanted.empty() || wanted == client.player.id) result["username"] = client.player.username;

    send(client, "stats", result);
  }

  bool handleRoomMessage(Client& client, const std::string& type, const json& data)
  {
    if (type == "mp_createRoom") handleCreateRoom(client, data);
    else if (type == "mp_joinRoom") handleJoinRoom(client, data);
    else if (type == "mp_leaveRoom") leaveRoom(client, "left");
    else if (type == "mp_listRooms") send(client, "mp_rooms", json{{"rooms", publicRoomsJson()}});
    else if (type == "mp_selectSong") handleSelectSong(client, data);
    else if (type == "mp_setReady") handleSetReady(client, data);
    else if (type == "mp_startSong") handleStartSong(client);
    else if (type == "mp_scoreUpdate") handleScoreUpdate(client, data);
    else if (type == "mp_relay") handleRelay(client, data);
    else if (type == "mp_playerFinished") handlePlayerFinished(client, data);
    else if (type == "mp_chat") handleChat(client, data);
    else if (type == "mp_kick") handleKick(client, data);
    else if (type == "mp_roomSettings") handleRoomSettings(client, data);
    else if (type == "mp_quickMatch") handleQuickMatch(client);
    else return false;

    return true;
  }

  void syncRoomIdentity(Client& client, const std::string& oldId)
  {
    Room* room = roomOf(client);

    if (room == nullptr) return;

    RoomMember* member = findMember(*room, client.serial);

    if (member == nullptr) return;

    member->id = client.player.id;
    member->username = client.player.username;
    member->avatarUrl = client.player.avatarUrl;
    member->authenticated = client.player.authenticated;

    sendToRoom(*room, "mp_memberUpdated", json{{"oldId", oldId}, {"member", memberJson(*room, *member)}, {"hostId", roomHostId(*room)}});
  }

  void recordScore(Client& client, const std::string& songId, const std::string& difficulty, int64_t score)
  {
    stats.recordSong(StatsBook::keyFor(client.player.authenticated, client.player.id, client.player.username), client.player.username, score, nowMs());

    ScoreEntry entry;
    entry.authenticated = client.player.authenticated;
    entry.id = client.player.authenticated ? client.player.id : "g:" + client.player.username;
    entry.username = client.player.username;
    entry.score = score;
    entry.at = nowMs();

    if (leaderboard.submit(songId, difficulty, entry)) log("new best for " + client.player.username + " on " + songId + " (" + difficulty + "): " + std::to_string(score));
  }

  void handleSongResult(Client& client, const json& data)
  {
    std::string songId = jsonString(data, "songId");
    std::string difficulty = jsonString(data, "difficulty");

    if (difficulty.empty()) difficulty = jsonString(data, "difficultyId");

    int64_t score = clampInt(jsonInt(data, "score", 0), 0, 2000000000);

    if (score > config.maxSongScore)
    {
      metrics.scoreViolations++;
      log("rejected song result from " + client.player.username + ": " + std::to_string(score));
      sendError(client, "score_rejected");
      return;
    }

    if (!validIdentifier(songId) || !validIdentifier(difficulty))
    {
      sendError(client, "invalid_song");
      return;
    }

    log("song result from " + client.player.username + ": " + songId + " " + difficulty + " " + std::to_string(score));

    recordScore(client, songId, difficulty, score);
  }

  void handleLeaderboard(Client& client, const json& data)
  {
    std::string songId = jsonString(data, "songId");
    std::string difficulty = jsonString(data, "difficulty");

    if (difficulty.empty()) difficulty = jsonString(data, "difficultyId");
    if (difficulty.empty()) difficulty = "normal";

    size_t limit = static_cast<size_t>(clampInt(jsonInt(data, "limit", 10), 1, static_cast<int64_t>(Leaderboard::MaxEntries)));

    send(client, "leaderboard", leaderboard.toJson(songId, difficulty, limit));
  }

  void tickRooms(int64_t now)
  {
    expireAwayMembers(now);

    std::vector<std::string> playing;

    for (const auto& entry : rooms)
    {
      if (entry.second.state == "playing") playing.push_back(entry.first);
    }

    for (const auto& roomId : playing)
    {
      Room* room = findRoom(roomId);

      if (room == nullptr) continue;

      bool timedOut = now - room->startedAt > static_cast<int64_t>(config.songTimeoutSeconds) * 1000;
      bool graceOver = room->firstFinishAt > 0 && now - room->firstFinishAt > static_cast<int64_t>(config.finishGraceSeconds) * 1000;

      if (timedOut || graceOver) finishRound(roomId);
    }

    if (now - lastScoreSave >= 3000)
    {
      lastScoreSave = now;

      if (leaderboard.isDirty()) saveLeaderboard();
      if (stats.isDirty()) saveStats();
    }

    if (now - lastAdminReset >= 60000)
    {
      lastAdminReset = now;
      adminFailures.clear();
      bans.purgeExpired(now);

      if (bans.isDirty()) saveBans();
    }
  }

  std::string statsPath() const
  {
    return (std::filesystem::path(config.dataDir) / "stats.json").string();
  }

  std::string bansPath() const
  {
    return (std::filesystem::path(config.dataDir) / "bans.json").string();
  }

  void saveStats()
  {
    if (!stats.save(statsPath())) log("could not write " + statsPath());
  }

  void saveBans()
  {
    if (!bans.save(bansPath(), nowMs())) log("could not write " + bansPath());
  }

  void saveAll()
  {
    if (leaderboard.isDirty()) saveLeaderboard();
    if (stats.isDirty()) saveStats();
    if (bans.isDirty()) saveBans();
  }

  void announceShutdown()
  {
    broadcast("server_notice", json{{"text", "The server is restarting. Your room will wait for you for a moment."}, {"kind", "shutdown"}}, 0);

    int64_t deadline = nowMs() + 500;

    while (nowMs() < deadline)
    {
      bool pending = false;

      for (auto& entry : clients)
      {
        Client& other = *entry.second;

        if (!other.closing && !other.output.empty())
        {
          flushClient(other);
          pending = pending || !other.output.empty();
        }
      }

      if (!pending) break;

      std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }
  }

  std::string leaderboardPath() const
  {
    return (std::filesystem::path(config.dataDir) / "scores.json").string();
  }

  void saveLeaderboard()
  {
    if (!leaderboard.save(leaderboardPath())) log("could not write " + leaderboardPath());
  }

  void handleJoin(Client& client, const json& data)
  {
    if (client.joined)
    {
      sendError(client, "already_joined");
      return;
    }

    if (joinedCount() >= config.maxPlayers)
    {
      sendError(client, "server_full");
      closeClient(client, "server full");
      return;
    }

    std::string username = sanitizeText(jsonString(data, "username"), 32);
    std::string platform = sanitizeText(jsonString(data, "platform"), 24);
    std::string activity = sanitizeText(jsonString(data, "activity"), 64);

    const Ban* addressBan = bans.find(BanList::ipKey(client.remote), nowMs());

    if (addressBan != nullptr)
    {
      refuseBanned(client, *addressBan);
      return;
    }

    std::string previousKey = sanitizeText(jsonString(data, "resumeKey"), 64);

    client.player.id = "p" + std::to_string(nextPlayer++);
    client.player.username = username.empty() ? "Guest" + client.player.id.substr(1) : username;
    client.player.platform = platform.empty() ? "Unknown" : platform;
    client.player.activity = activity.empty() ? "Idle" : activity;
    client.player.lastSeen = nowMs();
    client.joined = true;

    std::string token = jsonString(data, "token");
    bool resumed = false;

    if (!token.empty())
    {
      auto session = findSession(token);

      if (session != nullptr)
      {
        const Ban* accountBan = bans.find("d" + session->profile.id, nowMs());

        if (accountBan != nullptr)
        {
          client.joined = false;
          refuseBanned(client, *accountBan);
          return;
        }

        applyIdentity(client, session->profile, sha256Hex(token), false);
        resumed = true;
      }
    }

    Room* resumeRoomPtr = nullptr;
    RoomMember* resumeMember = nullptr;

    std::string resumeRoomId;
    std::string resumeMemberId;

    if (resumeRoom(client, previousKey, resumeMember, resumeRoomPtr) && resumeRoomPtr != nullptr && resumeMember != nullptr)
    {
      resumeRoomId = resumeRoomPtr->id;
      resumeMemberId = resumeMember->id;

      if (!client.player.authenticated)
      {
        client.player.id = resumeMember->id;
        client.player.username = resumeMember->username;
      }
    }

    client.resumeKey = randomHex(16);
    metrics.joins++;

    stats.touch(StatsBook::keyFor(client.player.authenticated, client.player.id, client.player.username), client.player.username, nowMs());

    log("player joined: " + client.player.username + " (" + client.player.id + ")" + (resumed ? " [discord]" : "") + (!resumeRoomId.empty() ? " [resumed]" : "") + ", " +
        std::to_string(joinedCount()) + " online");

    json welcome = {{"protocol", ProtocolVersion},
                    {"id", client.player.id},
                    {"authenticated", client.player.authenticated},
                    {"serverName", config.serverName},
                    {"motd", config.motd},
                    {"discordEnabled", config.discord.enabled()},
                    {"players", joinedCount()},
                    {"features", json::array({"rooms", "chat", "leaderboard", "resume", "quickmatch", "stats"})},
                    {"maxRoomPlayers", config.maxRoomPlayers},
                    {"minPlayersToStart", config.minPlayersToStart},
                    {"resumeKey", client.resumeKey},
                    {"resumed", !resumeRoomId.empty()},
                    {"reconnectGraceSeconds", config.reconnectGraceSeconds}};

    if (client.player.authenticated)
    {
      welcome["profile"] = Profile{client.discordId, client.player.username, client.player.avatarUrl}.toJson();
    }

    send(client, "welcome", welcome);
    send(client, "activeUsers", json{{"users", playersJson()}});
    broadcast("userJoined", client.player.toJson(), client.serial);

    if (!resumeRoomId.empty()) completeResume(client, resumeRoomId, resumeMemberId);
  }

  void completeResume(Client& client, const std::string& roomId, const std::string& memberId)
  {
    Room* roomPtr = findRoom(roomId);

    if (roomPtr == nullptr) return;

    Room& room = *roomPtr;
    RoomMember* memberPtr = findAwayMemberById(room, memberId);

    if (memberPtr == nullptr) return;

    RoomMember& member = *memberPtr;

    member.away = false;
    member.awayUntil = 0;
    member.resumeKey.clear();
    member.serial = client.serial;
    member.authenticated = client.player.authenticated;
    member.username = client.player.username;
    member.avatarUrl = client.player.avatarUrl;

    if (room.hostSerial == 0) room.hostSerial = client.serial;

    client.roomId = roomId;
    metrics.reconnects++;

    json message = roomJson(room);

    if (member.missedResults && !room.lastResults.is_null())
    {
      message["results"] = room.lastResults;
      member.missedResults = false;
    }

    log(client.player.username + " came back to room " + roomId);

    send(client, "mp_roomResumed", message);

    Room* current = findRoom(roomId);

    if (current == nullptr) return;

    RoomMember* back = findMember(*current, client.serial);

    if (back != nullptr) sendToRoom(*current, "mp_playerBack", json{{"userId", memberId}, {"member", memberJson(*current, *back)}, {"hostId", roomHostId(*current)}}, client.serial);
  }

  void refuseBanned(Client& client, const Ban& ban)
  {
    metrics.bannedRefusals++;

    log("refused banned connection from " + client.remote);

    client.forceLeave = true;

    send(client, "error", json{{"reason", "banned"}, {"detail", ban.reason}, {"until", ban.expires}});
    closeClient(client, "banned");
  }

  void handleActivity(Client& client, const json& data)
  {
    std::string activity = sanitizeText(jsonString(data, "activity"), 64);

    if (activity.empty()) return;

    client.player.activity = activity;
    client.player.lastSeen = nowMs();

    broadcast("userUpdated", client.player.toJson(), client.serial);
  }

  const Session* findSession(const std::string& token)
  {
    auto it = sessions.find(sha256Hex(token));

    if (it == sessions.end()) return nullptr;

    if (it->second.expires < nowMs())
    {
      sessions.erase(it);
      saveSessions();
      return nullptr;
    }

    return &it->second;
  }

  void applyIdentity(Client& client, const Profile& profile, const std::string& tokenHash, bool announce)
  {
    auto existing = discordClients.find(profile.id);

    if (existing != discordClients.end() && existing->second != client.serial)
    {
      Client* other = findClient(existing->second);

      if (other != nullptr)
      {
        sendError(*other, "logged_in_elsewhere");
        other->closing = true;
        detach(*other);
      }

      discordClients.erase(profile.id);
    }

    std::string oldId = client.player.id;

    client.discordId = profile.id;
    client.tokenHash = tokenHash;
    client.player.id = "d" + profile.id;
    client.player.username = profile.username;
    client.player.avatarUrl = profile.avatarUrl;
    client.player.authenticated = true;
    discordClients[profile.id] = client.serial;

    if (announce && oldId != client.player.id)
    {
      broadcast("userLeft", json{{"id", oldId}}, 0);
      broadcast("userJoined", client.player.toJson(), 0);
    }

    if (oldId != client.player.id) syncRoomIdentity(client, oldId);
  }

  void handleAuthBegin(Client& client)
  {
    if (!config.discord.enabled())
    {
      send(client, "auth_error", json{{"reason", "discord_not_configured"}});
      return;
    }

    if (client.player.authenticated)
    {
      send(client, "auth_error", json{{"reason", "already_authenticated"}});
      return;
    }

    if (!client.pendingState.empty()) pendingAuth.erase(client.pendingState);

    std::string state = randomHex(16);

    client.pendingState = state;
    pendingAuth[state] = PendingAuth{client.serial, nowMs() + AuthTtlMs};

    std::string url = config.discord.authorizeBase + "?client_id=" + urlEncode(config.discord.clientId) + "&response_type=code&scope=identify&redirect_uri=" +
                      urlEncode(config.discord.redirectUri) + "&state=" + state;

    send(client, "auth_url", json{{"url", url}, {"state", state}, {"expiresIn", AuthTtlMs / 1000}});
  }

  void handleAuthResume(Client& client, const std::string& token)
  {
    const Session* session = token.empty() ? nullptr : findSession(token);

    if (session == nullptr)
    {
      send(client, "auth_error", json{{"reason", "invalid_token"}});
      return;
    }

    Profile profile = session->profile;

    const Ban* accountBan = bans.find("d" + profile.id, nowMs());

    if (accountBan != nullptr)
    {
      refuseBanned(client, *accountBan);
      return;
    }

    applyIdentity(client, profile, sha256Hex(token), true);

    send(client, "auth_ok", json{{"profile", profile.toJson()}, {"token", token}, {"id", client.player.id}});
  }

  void handleAuthLogout(Client& client)
  {
    if (!client.player.authenticated)
    {
      send(client, "auth_logged_out", json::object());
      return;
    }

    sessions.erase(client.tokenHash);
    saveSessions();

    std::string oldId = client.player.id;

    discordClients.erase(client.discordId);
    client.discordId.clear();
    client.tokenHash.clear();
    client.player.authenticated = false;
    client.player.avatarUrl.clear();
    client.player.id = "p" + std::to_string(nextPlayer++);
    client.player.username = "Guest" + client.player.id.substr(1);

    syncRoomIdentity(client, oldId);

    broadcast("userLeft", json{{"id", oldId}}, 0);
    broadcast("userJoined", client.player.toJson(), 0);

    send(client, "auth_logged_out", json{{"id", client.player.id}, {"username", client.player.username}});
  }

  void readHttp(HttpConn& conn)
  {
    char buffer[2048];

    for (;;)
    {
      int received = net::receiveSome(conn.socket, buffer, sizeof(buffer));

      if (received > 0)
      {
        conn.input.append(buffer, static_cast<size_t>(received));

        if (conn.input.size() > MaxHttpBytes)
        {
          respond(conn, 431, "text/plain", "request too large");
          return;
        }

        if (conn.input.find("\r\n\r\n") != std::string::npos)
        {
          handleHttp(conn);
          return;
        }

        continue;
      }

      if (received == 0 || !net::wouldBlock()) conn.closing = true;

      return;
    }
  }

  void respond(HttpConn& conn, int status, const std::string& contentType, const std::string& body)
  {
    const char* reason = status == 200   ? "OK"
                         : status == 400 ? "Bad Request"
                         : status == 401 ? "Unauthorized"
                         : status == 404 ? "Not Found"
                         : status == 405 ? "Method Not Allowed"
                         : status == 429 ? "Too Many Requests"
                                         : "Error";

    conn.output = "HTTP/1.1 " + std::to_string(status) + " " + reason + "\r\nContent-Type: " + contentType + "; charset=utf-8\r\nContent-Length: " +
                  std::to_string(body.size()) +
                  "\r\nConnection: close\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nReferrer-Policy: no-referrer\r\n"
                  "Content-Security-Policy: default-src 'none'; style-src 'unsafe-inline'\r\n\r\n" +
                  body;
    conn.waiting = false;
    conn.closeWhenFlushed = true;

    flushHttp(conn);
  }

  void flushHttp(HttpConn& conn)
  {
    while (!conn.output.empty())
    {
      int sent = net::sendSome(conn.socket, conn.output.data(), conn.output.size());

      if (sent > 0)
      {
        conn.output.erase(0, static_cast<size_t>(sent));
        continue;
      }

      if (sent < 0 && net::wouldBlock()) return;

      conn.output.clear();
      conn.closing = true;
      return;
    }

    if (conn.closeWhenFlushed) conn.closing = true;
  }

  void handleHttp(HttpConn& conn)
  {
    size_t position = 0;
    std::string method = firstToken(conn.input, position);
    std::string target = firstToken(conn.input, position);

    metrics.httpRequests++;

    std::string path = target;
    std::string query;
    size_t question = target.find('?');

    if (question != std::string::npos)
    {
      path = target.substr(0, question);
      query = target.substr(question + 1);
    }

    bool adminPath = path.rfind("/admin/", 0) == 0;

    if (method != "GET" && !(method == "POST" && adminPath))
    {
      respond(conn, 405, "text/plain", "method not allowed");
      return;
    }

    if (adminPath)
    {
      handleAdmin(conn, path, parseQuery(query), headerValue(conn.input, "Authorization"));
    }
    else if (path == "/health")
    {
      respond(conn, 200, "text/plain", "ok");
    }
    else if (path == "/metrics")
    {
      respond(conn, 200, "text/plain", metricsText());
    }
    else if (path == "/player")
    {
      auto params = parseQuery(query);
      std::string id = params.count("id") ? params["id"] : std::string();

      if (id.empty()) respond(conn, 400, "application/json", dumpJson(json{{"error", "missing_id"}}));
      else respond(conn, 200, "application/json", dumpJson(statsJson(statsKeyFor(id), id)));
    }
    else if (path == "/status")
    {
      size_t authenticated = 0;

      for (const auto& entry : clients)
      {
        if (entry.second->joined && !entry.second->closing && entry.second->player.authenticated) authenticated++;
      }

      json status = {{"name", config.serverName},
                     {"protocol", ProtocolVersion},
                     {"online", joinedCount()},
                     {"authenticated", authenticated},
                     {"rooms", rooms.size()},
                     {"playing", playingRooms()},
                     {"maxPlayers", config.maxPlayers},
                     {"discordEnabled", config.discord.enabled()},
                     {"uptimeSeconds", (nowMs() - startedAt) / 1000}};

      respond(conn, 200, "application/json", dumpJson(status));
    }
    else if (path == "/rooms")
    {
      respond(conn, 200, "application/json", dumpJson(json{{"rooms", publicRoomsJson()}}));
    }
    else if (path == "/leaderboard")
    {
      auto params = parseQuery(query);
      std::string songId = params.count("song") ? params["song"] : std::string();
      std::string difficulty = params.count("difficulty") ? params["difficulty"] : std::string("normal");

      respond(conn, 200, "application/json", dumpJson(leaderboard.toJson(songId, difficulty, 25)));
    }
    else if (path == "/auth/callback")
    {
      handleAuthCallback(conn, parseQuery(query));
    }
    else
    {
      respond(conn, 404, "text/plain", "not found");
    }
  }

  std::string metricsText()
  {
    std::string text;

    auto line = [&](const char* name, const char* kind, uint64_t value) {
      text += std::string("# TYPE ") + name + " " + kind + "\n" + name + " " + std::to_string(value) + "\n";
    };

    line("moon_players_online", "gauge", joinedCount());
    line("moon_rooms", "gauge", rooms.size());
    line("moon_rooms_playing", "gauge", playingRooms());
    line("moon_uptime_seconds", "gauge", static_cast<uint64_t>((nowMs() - startedAt) / 1000));
    line("moon_known_players", "gauge", stats.size());
    line("moon_active_bans", "gauge", bans.size());
    line("moon_connections_total", "counter", metrics.connections);
    line("moon_messages_total", "counter", metrics.messages);
    line("moon_joins_total", "counter", metrics.joins);
    line("moon_rooms_created_total", "counter", metrics.roomsCreated);
    line("moon_rounds_started_total", "counter", metrics.roundsStarted);
    line("moon_rounds_finished_total", "counter", metrics.roundsFinished);
    line("moon_reconnects_total", "counter", metrics.reconnects);
    line("moon_score_violations_total", "counter", metrics.scoreViolations);
    line("moon_rate_limited_total", "counter", metrics.rateLimited);
    line("moon_banned_refusals_total", "counter", metrics.bannedRefusals);
    line("moon_http_requests_total", "counter", metrics.httpRequests);

    return text;
  }

  Client* findClientByPlayerId(const std::string& id)
  {
    for (auto& entry : clients)
    {
      Client& other = *entry.second;

      if (other.joined && !other.closing && other.player.id == id) return &other;
    }

    return nullptr;
  }

  void removeFromServer(Client& target, const std::string& reason, const std::string& detail)
  {
    target.forceLeave = true;

    send(target, "error", json{{"reason", reason}, {"detail", detail}});
    closeClient(target, reason);
  }

  void handleAdmin(HttpConn& conn, const std::string& path, std::map<std::string, std::string> params, const std::string& authorization)
  {
    if (config.adminToken.empty())
    {
      respond(conn, 404, "text/plain", "not found");
      return;
    }

    size_t& failures = adminFailures[conn.remote];

    if (failures >= MaxAdminAttempts)
    {
      respond(conn, 429, "application/json", dumpJson(json{{"error", "too_many_attempts"}}));
      return;
    }

    std::string supplied = params.count("token") ? params["token"] : std::string();

    if (authorization.rfind("Bearer ", 0) == 0) supplied = authorization.substr(7);

    if (!sameSecret(supplied, config.adminToken))
    {
      failures++;
      log("admin request refused from " + conn.remote);
      respond(conn, 401, "application/json", dumpJson(json{{"error", "unauthorized"}}));
      return;
    }

    auto get = [&](const char* key) {
      auto it = params.find(key);
      return it == params.end() ? std::string() : it->second;
    };

    std::string action = path.substr(7);

    if (action == "players")
    {
      json list = json::array();

      for (const auto& entry : clients)
      {
        const Client& other = *entry.second;

        if (!other.joined || other.closing) continue;

        json item = other.player.toJson();
        item["address"] = other.remote;
        item["roomId"] = other.roomId;
        item["connectedAt"] = other.connectedAt;
        list.push_back(item);
      }

      respond(conn, 200, "application/json", dumpJson(json{{"players", list}}));
    }
    else if (action == "bans")
    {
      respond(conn, 200, "application/json", dumpJson(json{{"bans", bans.toJson(nowMs())}}));
    }
    else if (action == "kick")
    {
      Client* target = findClientByPlayerId(get("id"));

      if (target == nullptr)
      {
        respond(conn, 404, "application/json", dumpJson(json{{"error", "unknown_player"}}));
        return;
      }

      log("admin kicked " + target->player.username);
      removeFromServer(*target, "kicked", get("reason"));
      respond(conn, 200, "application/json", dumpJson(json{{"ok", true}}));
    }
    else if (action == "drop")
    {
      Client* target = findClientByPlayerId(get("id"));

      if (target == nullptr)
      {
        respond(conn, 404, "application/json", dumpJson(json{{"error", "unknown_player"}}));
        return;
      }

      log("admin dropped the connection of " + target->player.username);
      closeClient(*target, "dropped by an admin");
      respond(conn, 200, "application/json", dumpJson(json{{"ok", true}}));
    }
    else if (action == "ban")
    {
      std::string key = get("key");

      if (key.empty())
      {
        Client* target = findClientByPlayerId(get("id"));

        if (target == nullptr)
        {
          respond(conn, 404, "application/json", dumpJson(json{{"error", "unknown_player"}}));
          return;
        }

        key = target->player.authenticated && get("scope") != "ip" ? "d" + target->discordId : BanList::ipKey(target->remote);
      }

      int64_t minutes = 0;

      try
      {
        minutes = get("minutes").empty() ? 0 : std::stoll(get("minutes"));
      }
      catch (...)
      {
        minutes = 0;
      }

      if (!bans.add(key, sanitizeText(get("reason"), 120), nowMs(), minutes * 60 * 1000))
      {
        respond(conn, 400, "application/json", dumpJson(json{{"error", "invalid_key"}}));
        return;
      }

      log("admin banned " + key + (minutes > 0 ? " for " + std::to_string(minutes) + " minutes" : " permanently"));
      saveBans();

      std::vector<uint64_t> victims;

      for (const auto& entry : clients)
      {
        const Client& other = *entry.second;

        if (other.closing) continue;

        bool byIp = key.rfind("ip:", 0) == 0 && BanList::ipKey(other.remote) == key;
        bool byAccount = key[0] == 'd' && !other.discordId.empty() && other.discordId == key.substr(1);

        if (byIp || byAccount) victims.push_back(other.serial);
      }

      for (uint64_t serial : victims)
      {
        Client* victim = findClient(serial);

        if (victim != nullptr) removeFromServer(*victim, "banned", get("reason"));
      }

      respond(conn, 200, "application/json", dumpJson(json{{"ok", true}, {"key", key}, {"removed", victims.size()}}));
    }
    else if (action == "unban")
    {
      bool removed = bans.remove(get("key"));

      if (removed) saveBans();

      respond(conn, removed ? 200 : 404, "application/json", dumpJson(json{{"ok", removed}}));
    }
    else if (action == "announce")
    {
      std::string text = sanitizeText(get("text"), 200);

      if (text.empty())
      {
        respond(conn, 400, "application/json", dumpJson(json{{"error", "missing_text"}}));
        return;
      }

      log("admin announcement: " + text);
      broadcast("server_notice", json{{"text", text}, {"kind", "announcement"}}, 0);
      respond(conn, 200, "application/json", dumpJson(json{{"ok", true}}));
    }
    else if (action == "closeRoom")
    {
      std::string code = normalizeRoomCode(get("room"));
      Room* room = findRoom(code);

      if (room == nullptr)
      {
        respond(conn, 404, "application/json", dumpJson(json{{"error", "not_found"}}));
        return;
      }

      std::vector<uint64_t> serials;

      for (const auto& member : room->members)
      {
        if (member.serial != 0) serials.push_back(member.serial);
      }

      rooms.erase(code);

      for (uint64_t serial : serials)
      {
        Client* member = findClient(serial);

        if (member == nullptr) continue;

        member->roomId.clear();
        send(*member, "mp_roomClosed", json{{"reason", "closed_by_admin"}});
      }

      log("admin closed room " + code);
      respond(conn, 200, "application/json", dumpJson(json{{"ok", true}, {"removed", serials.size()}}));
    }
    else
    {
      respond(conn, 404, "application/json", dumpJson(json{{"error", "unknown_action"}}));
    }
  }

  void handleAuthCallback(HttpConn& conn, const std::map<std::string, std::string>& params)
  {
    auto get = [&](const char* key) {
      auto it = params.find(key);
      return it == params.end() ? std::string() : it->second;
    };

    std::string state = get("state");
    std::string code = get("code");
    std::string denied = get("error");

    auto pending = pendingAuth.find(state);

    if (state.empty() || pending == pendingAuth.end() || pending->second.expires < nowMs())
    {
      respond(conn, 400, "text/html", resultPage(false, "Login expired", "This login link is no longer valid. Go back to the game and start the login again."));
      return;
    }

    uint64_t clientSerial = pending->second.clientSerial;
    pendingAuth.erase(pending);

    Client* client = findClient(clientSerial);

    if (client != nullptr) client->pendingState.clear();

    if (!denied.empty() || code.empty())
    {
      if (client != nullptr) send(*client, "auth_error", json{{"reason", denied.empty() ? "missing_code" : denied}});

      respond(conn, 400, "text/html", resultPage(false, "Login cancelled", "Discord did not authorize the login. You can close this tab and try again in the game."));
      return;
    }

    conn.waiting = true;
    activeJobs++;

    DiscordConfig discord = config.discord;
    uint64_t httpSerial = conn.serial;

    std::thread([this, discord, code, httpSerial, clientSerial]() {
      AuthResult result = exchangeDiscord(discord, code);

      {
        std::lock_guard<std::mutex> lock(jobMutex);
        completedJobs.push_back([this, httpSerial, clientSerial, result]() { finishAuth(httpSerial, clientSerial, result); });
      }

      activeJobs--;
    }).detach();
  }

  void finishAuth(uint64_t httpSerial, uint64_t clientSerial, const AuthResult& result)
  {
    HttpConn* conn = findHttp(httpSerial);
    Client* client = findClient(clientSerial);

    if (!result.ok)
    {
      if (client != nullptr && !client->closing) send(*client, "auth_error", json{{"reason", result.error}});

      if (conn != nullptr) respond(*conn, 400, "text/html", resultPage(false, "Login failed", "The server could not read your Discord profile. Try again in the game."));

      return;
    }

    const Ban* accountBan = bans.find("d" + result.profile.id, nowMs());

    if (accountBan != nullptr)
    {
      if (client != nullptr && !client->closing) refuseBanned(*client, *accountBan);

      if (conn != nullptr) respond(*conn, 400, "text/html", resultPage(false, "Login refused", "This account is banned from this server."));

      return;
    }

    std::string token = randomHex(32);
    Session session;
    session.profile = result.profile;
    session.expires = nowMs() + static_cast<int64_t>(config.sessionDays) * 24 * 60 * 60 * 1000;
    sessions[sha256Hex(token)] = session;
    saveSessions();

    log("discord login: " + result.profile.username + " (" + result.profile.id + ")");

    if (client != nullptr && !client->closing && client->joined && !client->detached)
    {
      applyIdentity(*client, result.profile, sha256Hex(token), true);
      send(*client, "auth_ok", json{{"profile", result.profile.toJson()}, {"token", token}, {"id", client->player.id}});
    }

    if (conn != nullptr)
    {
      respond(*conn, 200, "text/html", resultPage(true, "Logged in as " + result.profile.username, "You can close this tab and go back to the game."));
    }
  }

  void runCompletedJobs()
  {
    std::vector<std::function<void()>> jobs;

    {
      std::lock_guard<std::mutex> lock(jobMutex);
      jobs.swap(completedJobs);
    }

    for (auto& job : jobs) job();
  }

  size_t playingRooms() const
  {
    size_t count = 0;

    for (const auto& entry : rooms)
    {
      if (entry.second.state == "playing") count++;
    }

    return count;
  }

  void tick(int64_t now)
  {
    tickRooms(now);

    for (auto& entry : clients)
    {
      Client& client = *entry.second;

      if (client.closing) continue;

      if (!client.joined && now - client.connectedAt > JoinTimeoutMs) closeClient(client, "join timeout");
      else if (now - client.lastReceive > IdleTimeoutMs) closeClient(client, "idle timeout");
    }

    for (auto it = pendingAuth.begin(); it != pendingAuth.end();)
    {
      if (it->second.expires < now)
      {
        Client* client = findClient(it->second.clientSerial);

        if (client != nullptr && !client->closing)
        {
          client->pendingState.clear();
          send(*client, "auth_error", json{{"reason", "expired"}});
        }

        it = pendingAuth.erase(it);
      }
      else
      {
        ++it;
      }
    }

    for (auto& entry : httpConns)
    {
      HttpConn& conn = *entry.second;

      if (!conn.waiting && now - conn.createdAt > HttpTimeoutMs) conn.closing = true;
    }

    bool changed = false;

    for (auto it = sessions.begin(); it != sessions.end();)
    {
      if (it->second.expires < now)
      {
        it = sessions.erase(it);
        changed = true;
      }
      else
      {
        ++it;
      }
    }

    if (changed) saveSessions();
  }

  std::string sessionsPath() const
  {
    return (std::filesystem::path(config.dataDir) / "sessions.json").string();
  }

  void loadSessions()
  {
    std::ifstream file(sessionsPath());

    if (!file.good()) return;

    std::stringstream buffer;
    buffer << file.rdbuf();

    json root = json::parse(buffer.str(), nullptr, false);

    if (root.is_discarded() || !root.is_object() || !root.contains("sessions") || !root["sessions"].is_array()) return;

    int64_t now = nowMs();

    for (const auto& item : root["sessions"])
    {
      if (!item.is_object() || !item.contains("expires") || !item["expires"].is_number_integer()) continue;

      Session session;
      session.expires = item["expires"].get<int64_t>();
      session.profile.id = jsonString(item, "id");
      session.profile.username = jsonString(item, "username");
      session.profile.avatarUrl = jsonString(item, "avatarUrl");

      std::string hash = jsonString(item, "hash");

      if (hash.empty() || session.profile.id.empty() || session.expires < now) continue;

      sessions[hash] = session;
    }

    log("loaded " + std::to_string(sessions.size()) + " saved sessions");
  }

  void saveSessions()
  {
    json list = json::array();

    for (const auto& entry : sessions)
    {
      list.push_back(json{{"hash", entry.first},
                          {"id", entry.second.profile.id},
                          {"username", entry.second.profile.username},
                          {"avatarUrl", entry.second.profile.avatarUrl},
                          {"expires", entry.second.expires}});
    }

    std::string path = sessionsPath();
    std::string temp = path + ".tmp";

    {
      std::ofstream file(temp, std::ios::binary | std::ios::trunc);

      if (!file.good())
      {
        log("could not write " + temp);
        return;
      }

      file << dumpJson(json{{"sessions", list}});
    }

    std::error_code error;
    std::filesystem::rename(temp, path, error);

    if (error) log("could not replace " + path + ": " + error.message());
  }
};
}
}

int main(int argc, char** argv)
{
  moon::Config config;
  std::string error;

  if (!moon::loadConfig(argc, argv, config, error))
  {
    std::cerr << "error: " << error << "\nusage: moon-server [--config server.json] [--port N] [--http-port N] [--bind ADDRESS]" << std::endl;
    return 2;
  }

  if (!moon::net::init())
  {
    std::cerr << "error: could not initialize networking" << std::endl;
    return 1;
  }

  std::signal(SIGINT, moon::onSignal);
  std::signal(SIGTERM, moon::onSignal);

  moon::Server server(config);
  int code = server.run();

  moon::net::shutdown();

  return code;
}
