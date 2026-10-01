#pragma once

#include <cstdint>
#include <filesystem>
#include <fstream>
#include <map>
#include <sstream>
#include <string>

#include "../third_party/nlohmann/json.hpp"

namespace moon
{
struct Ban
{
  std::string reason;
  int64_t createdAt = 0;
  int64_t expires = 0;

  bool activeAt(int64_t now) const
  {
    return expires == 0 || expires > now;
  }
};

class BanList
{
public:
  static constexpr size_t MaxBans = 5000;

  static std::string ipKey(const std::string& address)
  {
    return "ip:" + address;
  }

  static bool validKey(const std::string& key)
  {
    if (key.size() < 3 || key.size() > 80) return false;

    if (key.rfind("ip:", 0) == 0) return key.size() > 3 && key.find_first_not_of("0123456789.:abcdefABCDEF", 3) == std::string::npos;

    if (key[0] != 'd') return false;

    return key.find_first_not_of("0123456789", 1) == std::string::npos;
  }

  bool add(const std::string& key, const std::string& reason, int64_t now, int64_t durationMs)
  {
    if (!validKey(key)) return false;
    if (bans.find(key) == bans.end() && bans.size() >= MaxBans) return false;

    Ban ban;
    ban.reason = reason;
    ban.createdAt = now;
    ban.expires = durationMs > 0 ? now + durationMs : 0;
    bans[key] = ban;
    dirty = true;

    return true;
  }

  bool remove(const std::string& key)
  {
    bool removed = bans.erase(key) > 0;

    if (removed) dirty = true;

    return removed;
  }

  const Ban* find(const std::string& key, int64_t now) const
  {
    auto it = bans.find(key);

    if (it == bans.end() || !it->second.activeAt(now)) return nullptr;

    return &it->second;
  }

  size_t purgeExpired(int64_t now)
  {
    size_t removed = 0;

    for (auto it = bans.begin(); it != bans.end();)
    {
      if (!it->second.activeAt(now))
      {
        it = bans.erase(it);
        removed++;
      }
      else
      {
        ++it;
      }
    }

    if (removed > 0) dirty = true;

    return removed;
  }

  size_t size() const
  {
    return bans.size();
  }

  bool isDirty() const
  {
    return dirty;
  }

  nlohmann::json toJson(int64_t now) const
  {
    nlohmann::json list = nlohmann::json::array();

    for (const auto& entry : bans)
    {
      if (!entry.second.activeAt(now)) continue;

      list.push_back(nlohmann::json{{"key", entry.first}, {"reason", entry.second.reason}, {"createdAt", entry.second.createdAt}, {"expires", entry.second.expires}});
    }

    return list;
  }

  void load(const std::string& path)
  {
    std::ifstream file(path);

    if (!file.good()) return;

    std::stringstream buffer;
    buffer << file.rdbuf();

    nlohmann::json root = nlohmann::json::parse(buffer.str(), nullptr, false);

    if (root.is_discarded() || !root.is_object() || !root.contains("bans") || !root["bans"].is_array()) return;

    for (const auto& item : root["bans"])
    {
      if (!item.is_object()) continue;

      std::string key = item.value("key", std::string());

      if (!validKey(key)) continue;

      Ban ban;
      ban.reason = item.value("reason", std::string());
      ban.createdAt = item.value("createdAt", static_cast<int64_t>(0));
      ban.expires = item.value("expires", static_cast<int64_t>(0));
      bans[key] = ban;
    }

    dirty = false;
  }

  bool save(const std::string& path, int64_t now)
  {
    std::string temp = path + ".tmp";

    {
      std::ofstream file(temp, std::ios::binary | std::ios::trunc);

      if (!file.good()) return false;

      file << nlohmann::json{{"bans", toJson(now)}}.dump(-1, ' ', false, nlohmann::json::error_handler_t::replace);
    }

    std::error_code error;
    std::filesystem::rename(temp, path, error);

    if (error) return false;

    dirty = false;

    return true;
  }

private:
  std::map<std::string, Ban> bans;
  bool dirty = false;
};
}
