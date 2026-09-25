#include "Content.hpp"

#include <algorithm>
#include <filesystem>
#include <string>
#include <vector>

static std::string joinSorted(std::vector<std::string> items)
{
  std::sort(items.begin(), items.end());

  std::string result;

  for (std::size_t i = 0; i < items.size(); i++)
  {
    if (i > 0) result += "\n";

    result += items[i];
  }

  return result;
}

static std::string scanDirectoryNames(const std::filesystem::path &root)
{
  std::vector<std::string> names;
  std::error_code ec;

  if (!std::filesystem::exists(root, ec) || ec || !std::filesystem::is_directory(root, ec) || ec)
  {
    return "";
  }

  std::filesystem::directory_iterator it(root, ec);
  std::filesystem::directory_iterator end;

  if (ec) return "";

  for (; it != end; it.increment(ec))
  {
    if (ec) break;

    if (it->is_directory())
    {
      names.push_back(it->path().filename().string());
    }
  }

  return joinSorted(names);
}

static std::string scanJsonFileStems(const std::filesystem::path &root)
{
  std::vector<std::string> names;
  std::error_code ec;

  if (!std::filesystem::exists(root, ec) || ec || !std::filesystem::is_directory(root, ec) || ec)
  {
    return "";
  }

  std::filesystem::directory_iterator it(root, ec);
  std::filesystem::directory_iterator end;

  if (ec) return "";

  for (; it != end; it.increment(ec))
  {
    if (ec) break;

    if (it->is_regular_file() && it->path().extension() == ".json")
    {
      names.push_back(it->path().stem().string());
    }
  }

  return joinSorted(names);
}

static std::string subdirectoriesResult;
static std::string jsonFilesResult;
static std::string songsResult;
static std::string weeksResult;
static std::string charactersResult;

extern "C" const char *funkin_content_scanSubdirectories(const char *assetsRoot, const char *relativePath)
{
  std::filesystem::path root = std::filesystem::path(assetsRoot) / relativePath;
  subdirectoriesResult = scanDirectoryNames(root);
  return subdirectoriesResult.c_str();
}

extern "C" const char *funkin_content_scanJsonFiles(const char *assetsRoot, const char *relativePath)
{
  std::filesystem::path root = std::filesystem::path(assetsRoot) / relativePath;
  jsonFilesResult = scanJsonFileStems(root);
  return jsonFilesResult.c_str();
}

extern "C" const char *funkin_content_scanSongs(const char *assetsRoot)
{
  std::filesystem::path root = std::filesystem::path(assetsRoot) / "songs";
  songsResult = scanDirectoryNames(root);
  return songsResult.c_str();
}

extern "C" const char *funkin_content_scanWeeks(const char *assetsRoot)
{
  std::filesystem::path root = std::filesystem::path(assetsRoot) / "data" / "weeks";
  weeksResult = scanJsonFileStems(root);
  return weeksResult.c_str();
}

extern "C" const char *funkin_content_scanCharacters(const char *assetsRoot)
{
  std::filesystem::path root = std::filesystem::path(assetsRoot) / "data" / "characters";
  charactersResult = scanJsonFileStems(root);
  return charactersResult.c_str();
}
