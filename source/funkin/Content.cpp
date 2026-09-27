#include "Content.hpp"

#include <algorithm>
#include <string>
#include <vector>

#if defined(_WIN32)
#ifndef NOMINMAX
#define NOMINMAX
#endif
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#else
#include <dirent.h>
#include <sys/stat.h>
#endif

namespace
{
enum class EntryKind
{
  Directory,
  JsonFile
};

struct DirectoryEntry
{
  std::string name;
  bool isDirectory = false;
};

bool hasParentReference(const std::string &relativePath)
{
  std::size_t start = 0;

  while (start <= relativePath.size())
  {
    std::size_t end = relativePath.find_first_of("/\\", start);

    if (end == std::string::npos) end = relativePath.size();

    if (relativePath.compare(start, end - start, "..") == 0) return true;

    start = end + 1;
  }

  return false;
}

std::string joinPath(const char *assetsRoot, const char *relativePath)
{
  std::string root = assetsRoot != nullptr ? assetsRoot : "";
  std::string relative = relativePath != nullptr ? relativePath : "";

  if (relative.empty()) return root;

  if (root.empty()) return relative;

  char last = root.back();

  if (last != '/' && last != '\\') root += '/';

  return root + relative;
}

#if defined(_WIN32)
std::wstring toWide(const std::string &text)
{
  if (text.empty()) return std::wstring();

  int length = MultiByteToWideChar(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()), nullptr, 0);

  if (length <= 0) return std::wstring();

  std::wstring result(static_cast<std::size_t>(length), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()), &result[0], length);

  return result;
}

std::string toUtf8(const wchar_t *text)
{
  int length = WideCharToMultiByte(CP_UTF8, 0, text, -1, nullptr, 0, nullptr, nullptr);

  if (length <= 1) return std::string();

  std::string result(static_cast<std::size_t>(length), '\0');
  WideCharToMultiByte(CP_UTF8, 0, text, -1, &result[0], length, nullptr, nullptr);
  result.resize(static_cast<std::size_t>(length - 1));

  return result;
}

std::vector<DirectoryEntry> listDirectory(const std::string &path)
{
  std::vector<DirectoryEntry> entries;

  std::wstring pattern = toWide(path);

  if (pattern.empty()) return entries;

  if (pattern.back() != L'/' && pattern.back() != L'\\') pattern += L'\\';

  pattern += L'*';

  WIN32_FIND_DATAW data;
  HANDLE handle = FindFirstFileW(pattern.c_str(), &data);

  if (handle == INVALID_HANDLE_VALUE) return entries;

  do
  {
    std::string name = toUtf8(data.cFileName);

    if (name.empty() || name == "." || name == "..") continue;

    DirectoryEntry entry;
    entry.name = name;
    entry.isDirectory = (data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0;
    entries.push_back(entry);
  } while (FindNextFileW(handle, &data) != 0);

  FindClose(handle);

  return entries;
}
#else
std::vector<DirectoryEntry> listDirectory(const std::string &path)
{
  std::vector<DirectoryEntry> entries;

  DIR *directory = opendir(path.c_str());

  if (directory == nullptr) return entries;

  while (dirent *item = readdir(directory))
  {
    std::string name = item->d_name;

    if (name == "." || name == "..") continue;

    struct stat info;
    std::string fullPath = path;

    if (fullPath.empty() || fullPath.back() != '/') fullPath += '/';

    fullPath += name;

    if (stat(fullPath.c_str(), &info) != 0) continue;

    DirectoryEntry entry;
    entry.name = name;
    entry.isDirectory = S_ISDIR(info.st_mode);

    if (!entry.isDirectory && !S_ISREG(info.st_mode)) continue;

    entries.push_back(entry);
  }

  closedir(directory);

  return entries;
}
#endif

bool endsWithJson(const std::string &name)
{
  static const std::string extension = ".json";

  return name.size() > extension.size() && name.compare(name.size() - extension.size(), extension.size(), extension) == 0;
}

std::string scanEntries(const std::string &path, EntryKind kind)
{
  std::vector<std::string> names;

  for (const DirectoryEntry &entry : listDirectory(path))
  {
    if (kind == EntryKind::Directory)
    {
      if (entry.isDirectory) names.push_back(entry.name);
    }
    else if (!entry.isDirectory && endsWithJson(entry.name))
    {
      names.push_back(entry.name.substr(0, entry.name.size() - 5));
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
    bool blocked = relativePath != nullptr && hasParentReference(relativePath);

    buffer = blocked ? std::string() : scanEntries(joinPath(assetsRoot, relativePath), kind);
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
