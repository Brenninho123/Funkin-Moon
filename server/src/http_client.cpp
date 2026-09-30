#include "http_client.hpp"

#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <winhttp.h>

namespace moon
{
namespace
{
std::wstring widen(const std::string& text)
{
  if (text.empty()) return std::wstring();

  int length = MultiByteToWideChar(CP_UTF8, 0, text.data(), static_cast<int>(text.size()), nullptr, 0);
  std::wstring result(static_cast<size_t>(length), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, text.data(), static_cast<int>(text.size()), &result[0], length);

  return result;
}

struct Handle
{
  HINTERNET value = nullptr;

  explicit Handle(HINTERNET handle = nullptr) : value(handle) {}

  Handle(const Handle&) = delete;
  Handle& operator=(const Handle&) = delete;

  ~Handle()
  {
    if (value != nullptr) WinHttpCloseHandle(value);
  }
};
}

HttpResponse httpRequest(const std::string& method, const std::string& url, const HttpHeaders& headers, const std::string& body, int timeoutMs)
{
  HttpResponse response;

  std::wstring wideUrl = widen(url);

  URL_COMPONENTS parts{};
  parts.dwStructSize = sizeof(parts);
  parts.dwHostNameLength = static_cast<DWORD>(-1);
  parts.dwUrlPathLength = static_cast<DWORD>(-1);
  parts.dwExtraInfoLength = static_cast<DWORD>(-1);

  if (!WinHttpCrackUrl(wideUrl.c_str(), 0, 0, &parts))
  {
    response.error = "invalid url";
    return response;
  }

  Handle session(WinHttpOpen(L"MoonEngineServer/1.0", WINHTTP_ACCESS_TYPE_DEFAULT_PROXY, WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0));

  if (session.value == nullptr)
  {
    response.error = "WinHttpOpen failed";
    return response;
  }

  WinHttpSetTimeouts(session.value, timeoutMs, timeoutMs, timeoutMs, timeoutMs);

  std::wstring host(parts.lpszHostName, parts.dwHostNameLength);
  Handle connection(WinHttpConnect(session.value, host.c_str(), parts.nPort, 0));

  if (connection.value == nullptr)
  {
    response.error = "could not connect";
    return response;
  }

  std::wstring path(parts.lpszUrlPath, parts.dwUrlPathLength);
  path.append(parts.lpszExtraInfo, parts.dwExtraInfoLength);

  if (path.empty()) path = L"/";

  DWORD flags = parts.nScheme == INTERNET_SCHEME_HTTPS ? WINHTTP_FLAG_SECURE : 0;
  Handle request(WinHttpOpenRequest(connection.value, widen(method).c_str(), path.c_str(), nullptr, WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES, flags));

  if (request.value == nullptr)
  {
    response.error = "could not open request";
    return response;
  }

  std::string headerText;

  for (const auto& header : headers) headerText += header.first + ": " + header.second + "\r\n";

  std::wstring wideHeaders = widen(headerText);
  DWORD bodySize = static_cast<DWORD>(body.size());

  BOOL sent = WinHttpSendRequest(request.value, wideHeaders.empty() ? WINHTTP_NO_ADDITIONAL_HEADERS : wideHeaders.c_str(),
                                 wideHeaders.empty() ? 0 : static_cast<DWORD>(-1), bodySize == 0 ? WINHTTP_NO_REQUEST_DATA : const_cast<char*>(body.data()),
                                 bodySize, bodySize, 0);

  if (!sent || !WinHttpReceiveResponse(request.value, nullptr))
  {
    response.error = "request failed (" + std::to_string(GetLastError()) + ")";
    return response;
  }

  DWORD status = 0;
  DWORD statusSize = sizeof(status);
  WinHttpQueryHeaders(request.value, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER, WINHTTP_HEADER_NAME_BY_INDEX, &status, &statusSize,
                      WINHTTP_NO_HEADER_INDEX);
  response.status = static_cast<int>(status);

  for (;;)
  {
    DWORD available = 0;

    if (!WinHttpQueryDataAvailable(request.value, &available) || available == 0) break;

    std::string chunk(available, '\0');
    DWORD read = 0;

    if (!WinHttpReadData(request.value, &chunk[0], available, &read) || read == 0) break;

    response.body.append(chunk.data(), read);

    if (response.body.size() > 4 * 1024 * 1024) break;
  }

  return response;
}
}

#else
#include <curl/curl.h>

namespace moon
{
namespace
{
size_t collect(char* data, size_t size, size_t count, void* target)
{
  std::string* buffer = static_cast<std::string*>(target);

  if (buffer->size() > 4 * 1024 * 1024) return 0;

  buffer->append(data, size * count);

  return size * count;
}
}

HttpResponse httpRequest(const std::string& method, const std::string& url, const HttpHeaders& headers, const std::string& body, int timeoutMs)
{
  HttpResponse response;

  CURL* curl = curl_easy_init();

  if (curl == nullptr)
  {
    response.error = "curl init failed";
    return response;
  }

  struct curl_slist* list = nullptr;

  for (const auto& header : headers) list = curl_slist_append(list, (header.first + ": " + header.second).c_str());

  curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
  curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, method.c_str());
  curl_easy_setopt(curl, CURLOPT_HTTPHEADER, list);
  curl_easy_setopt(curl, CURLOPT_TIMEOUT_MS, static_cast<long>(timeoutMs));
  curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 0L);
  curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1L);
  curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, collect);
  curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response.body);

  if (!body.empty())
  {
    curl_easy_setopt(curl, CURLOPT_POSTFIELDS, body.c_str());
    curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, static_cast<long>(body.size()));
  }

  CURLcode code = curl_easy_perform(curl);

  if (code != CURLE_OK)
  {
    response.error = curl_easy_strerror(code);
  }
  else
  {
    long status = 0;
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &status);
    response.status = static_cast<int>(status);
  }

  curl_slist_free_all(list);
  curl_easy_cleanup(curl);

  return response;
}
}
#endif
