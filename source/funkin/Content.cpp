#include "Content.hpp"

#include <algorithm>
#include <filesystem>
#include <string>
#include <system_error>
#include <vector>

namespace fs = std::filesystem;

namespace
{
enum class EntryKind
{
  Directory,
  JsonFile
};

std::string toUtf8(const fs::path &path)
{
  auto text = path.u8string();

  return std::string(text.begin(), text.end());
}

fs::path buildPath(const char *assetsRoot, const char *relativePath)
{
  fs::path root = assetsRoot != nullptr ? fs::u8path(assetsRoot) : fs::path();

  if (relativePath != nullptr && relativePath[0] != '\0')
  {
    root /= fs::u8path(relativePath);
  }

  return root.lexically_normal();
}

bool escapesRoot(const char *relativePath)
{
  if (relativePath == nullptr) return false;

  for (const fs::path &part : fs::u8path(relativePath))
  {
    if (part == "..") return true;
  }

  return false;
}

std::string scanEntries(const fs::path &root, EntryKind kind)
{
  std::error_code ec;

  if (!fs::is_directory(root, ec) || ec) return "";

  fs::directory_iterator it(root, fs::directory_options::skip_permission_denied, ec);

  if (ec) return "";

  std::vector<std::string> names;

  for (const fs::directory_iterator end; it != end; it.increment(ec))
  {
    if (ec) break;

    std::error_code entryEc;
    const fs::directory_entry &entry = *it;

    if (kind == EntryKind::Directory)
    {
      if (entry.is_directory(entryEc) && !entryEc)
      {
        names.push_back(toUtf8(entry.path().filename()));
      }
    }
    else if (entry.is_regular_file(entryEc) && !entryEc && entry.path().extension() == ".json")
    {
      names.push_back(toUtf8(entry.path().stem()));
    }
  }

  std::sort(names.begin(), names.end());

  std::string result;

  for (std::size_t i = 0; i < names.size(); i++)
  {
    if (i > 0) result += '\n';

    result += names[i];
  }

  return result;
}

const char *scanInto(std::string &buffer, const char *assetsRoot, const char *relativePath, EntryKind kind)
{
  try
  {
    buffer = escapesRoot(relativePath) ? std::string() : scanEntries(buildPath(assetsRoot, relativePath), kind);
  }
  catch (...)
  {
    buffer.clear();
  }

  return buffer.c_str();
}

thread_local std::string subdirectoriesResult;
thread_local std::string jsonFilesResult;
thread_local std::string songsResult;
thread_local std::string weeksResult;
thread_local std::string charactersResult;
} // namespace

extern "C" const char *funkin_content_scanSubdirectories(const char *assetsRoot, const char *relativePath)
{
  return scanInto(subdirectoriesResult, assetsRoot, relativePath, EntryKind::Directory);
}

extern "C" const char *funkin_content_scanJsonFiles(const char *assetsRoot, const char *relativePath)
{
  return scanInto(jsonFilesResult, assetsRoot, relativePath, EntryKind::JsonFile);
}

extern "C" const char *funkin_content_scanSongs(const char *assetsRoot)
{
  return scanInto(songsResult, assetsRoot, "songs", EntryKind::Directory);
}

extern "C" const char *funkin_content_scanWeeks(const char *assetsRoot)
{
  return scanInto(weeksResult, assetsRoot, "data/weeks", EntryKind::JsonFile);
}

extern "C" const char *funkin_content_scanCharacters(const char *assetsRoot)
{
  return scanInto(charactersResult, assetsRoot, "data/characters", EntryKind::JsonFile);
}
