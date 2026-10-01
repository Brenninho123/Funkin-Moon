#pragma once

#include <algorithm>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <map>
#include <sstream>
#include <string>
#include <vector>

#include "../third_party/nlohmann/json.hpp"

namespace moon
{
struct PlayerStats
{
  std::string username;
  int64_t roundsPlayed = 0;
  int64_t roundsWon = 0;
  int64_t songsFinished = 0;
  int64_t totalScore = 0;
  int64_t bestScore = 0;
  int64_t firstSeen = 0;
  int64_t lastSeen = 0;

  nlohmann::json toJson(const std::string& id) const
  {
    return nlohmann::json{{"id", id},
                          {"username", username},
                          {"roundsPlayed", roundsPlayed},
                          {"roundsWon", roundsWon},
                          {"songsFinished", songsFinished},
                          {"totalScore", totalScore},
                          {"bestScore", bestScore},
                          {"firstSeen", firstSeen},
                          {"lastSeen", lastSeen}};
  }
};

class StatsBook
{
public:
  static constexpr size_t MaxPlayers = 20000;

  static std::string keyFor(bool authenticated, const std::string& id, const std::string& username)
  {
    return authenticated ? id : "g:" + username;
  }

  void touch(const std::string& key, const std::string& username, int64_t now)
  {
    PlayerStats* stats = entry(key, username, now);

    if (stats != nullptr) stats->lastSeen = now;
  }

  void recordSong(const std::string& key, const std::string& username, int64_t score, int64_t now)
  {
    PlayerStats* stats = entry(key, username, now);

    if (stats == nullptr) return;

    stats->songsFinished++;
    stats->totalScore += std::max<int64_t>(score, 0);
    stats->bestScore = std::max(stats->bestScore, score);
    stats->lastSeen = now;
    dirty = true;
  }

  void recordRound(const std::string& key, const std::string& username, bool won, int64_t now)
  {
    PlayerStats* stats = entry(key, username, now);

    if (stats == nullptr) return;

    stats->roundsPlayed++;

    if (won) stats->roundsWon++;

    stats->lastSeen = now;
    dirty = true;
  }

  const PlayerStats* find(const std::string& key) const
  {
    auto it = players.find(key);

    return it == players.end() ? nullptr : &it->second;
  }

  size_t size() const
  {
    return players.size();
  }

  bool isDirty() const
  {
    return dirty;
  }

  void load(const std::string& path)
  {
    std::ifstream file(path);

    if (!file.good()) return;

    std::stringstream buffer;
    buffer << file.rdbuf();

    nlohmann::json root = nlohmann::json::parse(buffer.str(), nullptr, false);

    if (root.is_discarded() || !root.is_object() || !root.contains("players") || !root["players"].is_object()) return;

    for (auto it = root["players"].begin(); it != root["players"].end(); ++it)
    {
      if (!it.value().is_object() || it.key().empty() || it.key().size() > 80) continue;

      PlayerStats stats;
      stats.username = it.value().value("username", std::string());
      stats.roundsPlayed = it.value().value("roundsPlayed", static_cast<int64_t>(0));
      stats.roundsWon = it.value().value("roundsWon", static_cast<int64_t>(0));
      stats.songsFinished = it.value().value("songsFinished", static_cast<int64_t>(0));
      stats.totalScore = it.value().value("totalScore", static_cast<int64_t>(0));
      stats.bestScore = it.value().value("bestScore", static_cast<int64_t>(0));
      stats.firstSeen = it.value().value("firstSeen", static_cast<int64_t>(0));
      stats.lastSeen = it.value().value("lastSeen", static_cast<int64_t>(0));
      players[it.key()] = stats;
    }

    dirty = false;
  }

  bool save(const std::string& path)
  {
    nlohmann::json object = nlohmann::json::object();

    for (const auto& item : players) object[item.first] = item.second.toJson(item.first);

    std::string temp = path + ".tmp";

    {
      std::ofstream file(temp, std::ios::binary | std::ios::trunc);

      if (!file.good()) return false;

      file << nlohmann::json{{"players", object}}.dump(-1, ' ', false, nlohmann::json::error_handler_t::replace);
    }

    std::error_code error;
    std::filesystem::rename(temp, path, error);

    if (error) return false;

    dirty = false;

    return true;
  }

private:
  std::map<std::string, PlayerStats> players;
  bool dirty = false;

  PlayerStats* entry(const std::string& key, const std::string& username, int64_t now)
  {
    auto it = players.find(key);

    if (it == players.end())
    {
      if (players.size() >= MaxPlayers && !evictOldest()) return nullptr;

      PlayerStats stats;
      stats.firstSeen = now;
      stats.lastSeen = now;
      it = players.emplace(key, stats).first;
    }

    if (!username.empty() && it->second.username != username)
    {
      it->second.username = username;
      dirty = true;
    }

    return &it->second;
  }

  bool evictOldest()
  {
    auto oldest = players.end();

    for (auto it = players.begin(); it != players.end(); ++it)
    {
      if (oldest == players.end() || it->second.lastSeen < oldest->second.lastSeen) oldest = it;
    }

    if (oldest == players.end()) return false;

    players.erase(oldest);

    return true;
  }
};
}
