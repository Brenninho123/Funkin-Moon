#pragma once

#include <string>
#include <utility>
#include <vector>

namespace moon
{
struct HttpResponse
{
  int status = 0;
  std::string body;
  std::string error;

  bool ok() const
  {
    return error.empty() && status >= 200 && status < 300;
  }
};

using HttpHeaders = std::vector<std::pair<std::string, std::string>>;

HttpResponse httpRequest(const std::string& method, const std::string& url, const HttpHeaders& headers, const std::string& body, int timeoutMs = 10000);
}
