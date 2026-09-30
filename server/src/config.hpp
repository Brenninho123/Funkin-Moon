#pragma once

#include <cstdint>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>

#include "../third_party/nlohmann/json.hpp"

namespace moon
{
struct DiscordConfig
{
  std::string clientId;
  std::string clientSecret;
  std::string redirectUri;
  std::string apiBase = "https://discord.com/api";
  std::string authorizeBase = "https://discord.com/oauth2/authorize";
  std::string cdnBase = "https://cdn.discordapp.com";

  bool enabled() const
  {
    return !clientId.empty() && !clientSecret.empty() && !redirectUri.empty();
  }
};

struct Config
{
  std::string bindAddress = "0.0.0.0";
  uint16_t port = 7777;
  uint16_t httpPort = 8080;
  std::string publicUrl;
  std::string dataDir = "data";
  std::string serverName = "Moon Engine Server";
  std::string motd;
  size_t maxPlayers = 1024;
  size_t maxPerIp = 16;
  int sessionDays = 30;
  DiscordConfig discord;
};

namespace detail
{
inline std::string envValue(const char* name)
{
  const char* value = std::getenv(name);
  return value == nullptr ? std::string() : std::string(value);
}

inline std::string stringField(const nlohmann::json& object, const char* key, const std::string& fallback)
{
  auto it = object.find(key);

  if (it != object.end() && it->is_string()) return it->get<std::string>();

  return fallback;
}

inline int64_t intField(const nlohmann::json& object, const char* key, int64_t fallback)
{
  auto it = object.find(key);

  if (it != object.end() && it->is_number_integer()) return it->get<int64_t>();

  return fallback;
}

inline void overrideString(std::string& target, const char* envName)
{
  std::string value = envValue(envName);

  if (!value.empty()) target = value;
}

inline void overrideNumber(int64_t& target, const char* envName)
{
  std::string value = envValue(envName);

  if (value.empty()) return;

  try
  {
    target = std::stoll(value);
  }
  catch (...)
  {
  }
}
}

inline bool loadConfig(int argc, char** argv, Config& config, std::string& error)
{
  std::string configPath = "server.json";
  bool configRequired = false;
  int64_t portOverride = -1;
  int64_t httpPortOverride = -1;
  std::string bindOverride;

  for (int i = 1; i < argc; i++)
  {
    std::string arg = argv[i];
    bool hasValue = i + 1 < argc;

    if (arg == "--config" && hasValue)
    {
      configPath = argv[++i];
      configRequired = true;
    }
    else if (arg == "--port" && hasValue)
    {
      portOverride = std::atoll(argv[++i]);
    }
    else if (arg == "--http-port" && hasValue)
    {
      httpPortOverride = std::atoll(argv[++i]);
    }
    else if (arg == "--bind" && hasValue)
    {
      bindOverride = argv[++i];
    }
    else
    {
      error = "unknown or incomplete argument: " + arg;
      return false;
    }
  }

  std::ifstream file(configPath);

  if (file.good())
  {
    std::stringstream buffer;
    buffer << file.rdbuf();

    nlohmann::json root = nlohmann::json::parse(buffer.str(), nullptr, false);

    if (root.is_discarded() || !root.is_object())
    {
      error = "could not parse " + configPath;
      return false;
    }

    config.bindAddress = detail::stringField(root, "bindAddress", config.bindAddress);
    config.port = static_cast<uint16_t>(detail::intField(root, "port", config.port));
    config.httpPort = static_cast<uint16_t>(detail::intField(root, "httpPort", config.httpPort));
    config.publicUrl = detail::stringField(root, "publicUrl", config.publicUrl);
    config.dataDir = detail::stringField(root, "dataDir", config.dataDir);
    config.serverName = detail::stringField(root, "serverName", config.serverName);
    config.motd = detail::stringField(root, "motd", config.motd);
    config.maxPlayers = static_cast<size_t>(detail::intField(root, "maxPlayers", static_cast<int64_t>(config.maxPlayers)));
    config.maxPerIp = static_cast<size_t>(detail::intField(root, "maxPerIp", static_cast<int64_t>(config.maxPerIp)));
    config.sessionDays = static_cast<int>(detail::intField(root, "sessionDays", config.sessionDays));

    auto discord = root.find("discord");

    if (discord != root.end() && discord->is_object())
    {
      config.discord.clientId = detail::stringField(*discord, "clientId", config.discord.clientId);
      config.discord.clientSecret = detail::stringField(*discord, "clientSecret", config.discord.clientSecret);
      config.discord.redirectUri = detail::stringField(*discord, "redirectUri", config.discord.redirectUri);
      config.discord.apiBase = detail::stringField(*discord, "apiBase", config.discord.apiBase);
      config.discord.authorizeBase = detail::stringField(*discord, "authorizeBase", config.discord.authorizeBase);
      config.discord.cdnBase = detail::stringField(*discord, "cdnBase", config.discord.cdnBase);
    }
  }
  else if (configRequired)
  {
    error = "could not open " + configPath;
    return false;
  }

  int64_t port = config.port;
  int64_t httpPort = config.httpPort;
  int64_t maxPlayers = static_cast<int64_t>(config.maxPlayers);

  detail::overrideString(config.bindAddress, "MOON_BIND");
  detail::overrideNumber(port, "MOON_PORT");
  detail::overrideNumber(httpPort, "MOON_HTTP_PORT");
  detail::overrideNumber(maxPlayers, "MOON_MAX_PLAYERS");
  detail::overrideString(config.publicUrl, "MOON_PUBLIC_URL");
  detail::overrideString(config.dataDir, "MOON_DATA_DIR");
  detail::overrideString(config.serverName, "MOON_SERVER_NAME");
  detail::overrideString(config.discord.clientId, "MOON_DISCORD_CLIENT_ID");
  detail::overrideString(config.discord.clientSecret, "MOON_DISCORD_CLIENT_SECRET");
  detail::overrideString(config.discord.redirectUri, "MOON_DISCORD_REDIRECT_URI");
  detail::overrideString(config.discord.apiBase, "MOON_DISCORD_API_BASE");
  detail::overrideString(config.discord.authorizeBase, "MOON_DISCORD_AUTHORIZE_BASE");
  detail::overrideString(config.discord.cdnBase, "MOON_DISCORD_CDN_BASE");

  if (!bindOverride.empty()) config.bindAddress = bindOverride;
  if (portOverride >= 0) port = portOverride;
  if (httpPortOverride >= 0) httpPort = httpPortOverride;

  if (port < 0 || port > 65535 || httpPort < 0 || httpPort > 65535)
  {
    error = "port out of range";
    return false;
  }

  config.port = static_cast<uint16_t>(port);
  config.httpPort = static_cast<uint16_t>(httpPort);
  config.maxPlayers = static_cast<size_t>(maxPlayers < 1 ? 1 : maxPlayers);

  if (config.publicUrl.empty()) config.publicUrl = "http://127.0.0.1:" + std::to_string(config.httpPort);

  while (!config.publicUrl.empty() && config.publicUrl.back() == '/') config.publicUrl.pop_back();

  if (config.discord.redirectUri.empty() && !config.discord.clientId.empty()) config.discord.redirectUri = config.publicUrl + "/auth/callback";

  return true;
}
}
