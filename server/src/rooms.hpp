#pragma once

#include <algorithm>
#include <cctype>
#include <functional>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <map>
#include <sstream>
#include <string>
#include <vector>

#include "../third_party/nlohmann/json.hpp"
#include "util.hpp"

namespace moon
{
constexpr const char* RoomCodeAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
constexpr size_t RoomCodeLength = 5;

struct RoomMember
{
  uint64_t serial = 0;
  std::string id;
  std::string username;
  std::string avatarUrl;
  bool ready = false;
  bool finished = false;
  int64_t score = 0;
  int64_t combo = 0;
  double health = 0.0;
  double accuracy = 0.0;
  int64_t joinedAt = 0;
};

struct Room
{
  std::string id;
  std::string name;
  uint64_t hostSerial = 0;
  bool isPublic = true;
  size_t maxPlayers = 4;
  std::string state = "lobby";
  std::string songId;
  std::string difficultyId = "normal";
  std::string variation = "default";
  std::vector<RoomMember> members;
  int64_t createdAt = 0;
  int64_t startedAt = 0;
  int64_t firstFinishAt = 0;
  int64_t seed = 0;
  int round = 0;
};

struct RankedMember
{
  int rank = 0;
  RoomMember member;
};

inline std::string normalizeRoomCode(const std::string& input)
{
  std::string result;

  for (char c : input)
  {
    if (c == ' ' || c == '-') continue;

    result += static_cast<char>(std::toupper(static_cast<unsigned char>(c)));

    if (result.size() > 16) break;
  }

  return result;
}

inline std::string makeRoomCode(const std::function<uint32_t()>& random)
{
  std::string code;
  const size_t alphabetSize = std::char_traits<char>::length(RoomCodeAlphabet);

  for (size_t i = 0; i < RoomCodeLength; i++) code += RoomCodeAlphabet[random() % alphabetSize];

  return code;
}

inline RoomMember* findMember(Room& room, uint64_t serial)
{
  for (auto& member : room.members)
  {
    if (member.serial == serial) return &member;
  }

  return nullptr;
}

inline const RoomMember* findMember(const Room& room, uint64_t serial)
{
  for (const auto& member : room.members)
  {
    if (member.serial == serial) return &member;
  }

  return nullptr;
}

inline bool removeMember(Room& room, uint64_t serial)
{
  for (auto it = room.members.begin(); it != room.members.end(); ++it)
  {
    if (it->serial == serial)
    {
      room.members.erase(it);
      return true;
    }
  }

  return false;
}

inline bool everyoneFinished(const Room& room)
{
  if (room.members.empty()) return false;

  for (const auto& member : room.members)
  {
    if (!member.finished) return false;
  }

  return true;
}

inline bool everyoneReady(const Room& room)
{
  for (const auto& member : room.members)
  {
    if (member.serial != room.hostSerial && !member.ready) return false;
  }

  return true;
}

inline std::vector<RankedMember> rankMembers(const std::vector<RoomMember>& members)
{
  std::vector<RoomMember> sorted = members;

  std::stable_sort(sorted.begin(), sorted.end(), [](const RoomMember& a, const RoomMember& b) {
    if (a.finished != b.finished) return a.finished;
    if (a.score != b.score) return a.score > b.score;

    return a.accuracy > b.accuracy;
  });

  std::vector<RankedMember> ranked;

  for (size_t i = 0; i < sorted.size(); i++)
  {
    int rank = static_cast<int>(i) + 1;

    if (i > 0 && sorted[i].finished == sorted[i - 1].finished && sorted[i].score == sorted[i - 1].score && sorted[i].accuracy == sorted[i - 1].accuracy)
    {
      rank = ranked[i - 1].rank;
    }

    ranked.push_back(RankedMember{rank, sorted[i]});
  }

  return ranked;
}

inline bool validIdentifier(const std::string& value, size_t maxLength = 64)
{
  if (value.empty() || value.size() > maxLength) return false;

  for (char c : value)
  {
    if (!(std::isalnum(static_cast<unsigned char>(c)) || c == '_' || c == '-' || c == '.')) return false;
  }

  return true;
}

inline int64_t clampInt(int64_t value, int64_t low, int64_t high)
{
  return value < low ? low : (value > high ? high : value);
}

inline double clampDouble(double value, double low, double high)
{
  if (value != value) return low;

  return value < low ? low : (value > high ? high : value);
}

struct ScoreEntry
{
  std::string id;
  std::string username;
  int64_t score = 0;
  int64_t at = 0;
  bool authenticated = false;
};

class Leaderboard
{
public:
  static constexpr size_t MaxEntries = 25;
  static constexpr size_t MaxBoards = 5000;

  static std::string key(const std::string& songId, const std::string& difficulty)
  {
    return songId + "|" + difficulty;
  }

  bool submit(const std::string& songId, const std::string& difficulty, const ScoreEntry& entry)
  {
    if (!validIdentifier(songId) || !validIdentifier(difficulty) || entry.score <= 0) return false;

    std::string boardKey = key(songId, difficulty);

    if (boards.find(boardKey) == boards.end() && boards.size() >= MaxBoards) return false;

    std::vector<ScoreEntry>& board = boards[boardKey];

    for (auto& existing : board)
    {
      if (existing.id == entry.id)
      {
        if (entry.score <= existing.score) return false;

        existing = entry;
        sortBoard(board);
        dirty = true;

        return true;
      }
    }

    board.push_back(entry);
    sortBoard(board);

    if (board.size() > MaxEntries) board.resize(MaxEntries);

    dirty = true;

    return true;
  }

  nlohmann::json toJson(const std::string& songId, const std::string& difficulty, size_t limit) const
  {
    nlohmann::json entries = nlohmann::json::array();
    auto it = boards.find(key(songId, difficulty));

    if (it != boards.end())
    {
      for (size_t i = 0; i < it->second.size() && i < limit; i++)
      {
        const ScoreEntry& entry = it->second[i];

        entries.push_back(nlohmann::json{{"rank", i + 1},
                                         {"id", entry.id},
                                         {"username", entry.username},
                                         {"score", entry.score},
                                         {"at", entry.at},
                                         {"authenticated", entry.authenticated}});
      }
    }

    return nlohmann::json{{"songId", songId}, {"difficulty", difficulty}, {"entries", entries}};
  }

  size_t boardCount() const
  {
    return boards.size();
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

    if (root.is_discarded() || !root.is_object() || !root.contains("boards") || !root["boards"].is_object()) return;

    for (auto it = root["boards"].begin(); it != root["boards"].end(); ++it)
    {
      if (!it.value().is_array()) continue;

      std::vector<ScoreEntry> board;

      for (const auto& item : it.value())
      {
        if (!item.is_object() || !item.contains("score") || !item["score"].is_number_integer()) continue;

        ScoreEntry entry;
        entry.id = item.value("id", std::string());
        entry.username = item.value("username", std::string());
        entry.score = item["score"].get<int64_t>();
        entry.at = item.value("at", static_cast<int64_t>(0));
        entry.authenticated = item.value("authenticated", false);

        if (!entry.id.empty()) board.push_back(entry);
      }

      sortBoard(board);

      if (board.size() > MaxEntries) board.resize(MaxEntries);

      if (!board.empty()) boards[it.key()] = board;
    }

    dirty = false;
  }

  bool save(const std::string& path)
  {
    nlohmann::json object = nlohmann::json::object();

    for (const auto& board : boards)
    {
      nlohmann::json list = nlohmann::json::array();

      for (const auto& entry : board.second)
      {
        list.push_back(nlohmann::json{
          {"id", entry.id}, {"username", entry.username}, {"score", entry.score}, {"at", entry.at}, {"authenticated", entry.authenticated}});
      }

      object[board.first] = list;
    }

    std::string temp = path + ".tmp";

    {
      std::ofstream file(temp, std::ios::binary | std::ios::trunc);

      if (!file.good()) return false;

      file << nlohmann::json{{"boards", object}}.dump(-1, ' ', false, nlohmann::json::error_handler_t::replace);
    }

    std::error_code error;
    std::filesystem::rename(temp, path, error);

    if (error) return false;

    dirty = false;

    return true;
  }

private:
  std::map<std::string, std::vector<ScoreEntry>> boards;
  bool dirty = false;

  static void sortBoard(std::vector<ScoreEntry>& board)
  {
    std::stable_sort(board.begin(), board.end(), [](const ScoreEntry& a, const ScoreEntry& b) {
      if (a.score != b.score) return a.score > b.score;

      return a.at < b.at;
    });
  }
};
}
