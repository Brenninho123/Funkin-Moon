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
#include <thread>
#include <unordered_map>
#include <vector>

#include "config.hpp"
#include "http_client.hpp"
#include "net.hpp"
#include "util.hpp"

using json = nlohmann::json;

namespace moon
{
namespace
{
constexpr int ProtocolVersion = 1;
constexpr size_t MaxLineBytes = 65536;
constexpr size_t MaxOutputBytes = 1024 * 1024;
constexpr size_t MaxHttpBytes = 8192;
constexpr int64_t JoinTimeoutMs = 10000;
constexpr int64_t IdleTimeoutMs = 45000;
constexpr int64_t HttpTimeoutMs = 30000;
constexpr int64_t AuthTtlMs = 5 * 60 * 1000;
constexpr double RateBurst = 40.0;
constexpr double RatePerSecond = 20.0;
constexpr const char* UserAgent = "MoonEngineServer (https://github.com/Brenninho123/Funkin-Moon, 1.0)";

std::atomic<bool> gRunning{true};

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
};

struct PendingAuth
{
  uint64_t clientSerial = 0;
  int64_t expires = 0;
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
    loadSessions();

    log(config.serverName + " listening on " + config.bindAddress + ":" + std::to_string(config.port) + " (game) and :" + std::to_string(config.httpPort) + " (http)");
    log(config.discord.enabled() ? "discord login enabled, redirect uri " + config.discord.redirectUri : "discord login disabled (set MOON_DISCORD_CLIENT_ID and MOON_DISCORD_CLIENT_SECRET)");

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
      log("song result from " + client.player.username + ": " + dumpJson(data).substr(0, 200));
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
        applyIdentity(client, session->profile, sha256Hex(token), false);
        resumed = true;
      }
    }

    log("player joined: " + client.player.username + " (" + client.player.id + ")" + (resumed ? " [discord]" : "") + ", " + std::to_string(joinedCount()) + " online");

    json welcome = {{"protocol", ProtocolVersion},
                    {"id", client.player.id},
                    {"authenticated", client.player.authenticated},
                    {"serverName", config.serverName},
                    {"motd", config.motd},
                    {"discordEnabled", config.discord.enabled()},
                    {"players", joinedCount()}};

    if (client.player.authenticated)
    {
      welcome["profile"] = Profile{client.discordId, client.player.username, client.player.avatarUrl}.toJson();
    }

    send(client, "welcome", welcome);
    send(client, "activeUsers", json{{"users", playersJson()}});
    broadcast("userJoined", client.player.toJson(), client.serial);
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
    const char* reason = status == 200 ? "OK" : status == 400 ? "Bad Request" : status == 404 ? "Not Found" : status == 405 ? "Method Not Allowed" : "Error";

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

    if (method != "GET")
    {
      respond(conn, 405, "text/plain", "method not allowed");
      return;
    }

    std::string path = target;
    std::string query;
    size_t question = target.find('?');

    if (question != std::string::npos)
    {
      path = target.substr(0, question);
      query = target.substr(question + 1);
    }

    if (path == "/health")
    {
      respond(conn, 200, "text/plain", "ok");
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
                     {"maxPlayers", config.maxPlayers},
                     {"discordEnabled", config.discord.enabled()},
                     {"uptimeSeconds", (nowMs() - startedAt) / 1000}};

      respond(conn, 200, "application/json", dumpJson(status));
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

  void tick(int64_t now)
  {
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
