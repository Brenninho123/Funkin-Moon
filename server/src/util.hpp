#pragma once

#include <array>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <random>
#include <string>

namespace moon
{
inline int64_t nowMs()
{
  return std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::system_clock::now().time_since_epoch()).count();
}

inline std::string randomHex(size_t bytes)
{
  static const char digits[] = "0123456789abcdef";
  std::random_device device;
  std::string result;
  result.reserve(bytes * 2);

  for (size_t i = 0; i < bytes; i++)
  {
    unsigned int value = device() & 0xFF;
    result.push_back(digits[value >> 4]);
    result.push_back(digits[value & 0x0F]);
  }

  return result;
}

inline std::string urlEncode(const std::string& input)
{
  static const char digits[] = "0123456789ABCDEF";
  std::string result;

  for (unsigned char c : input)
  {
    if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.' || c == '~')
    {
      result.push_back(static_cast<char>(c));
    }
    else
    {
      result.push_back('%');
      result.push_back(digits[c >> 4]);
      result.push_back(digits[c & 0x0F]);
    }
  }

  return result;
}

inline int hexValue(char c)
{
  if (c >= '0' && c <= '9') return c - '0';
  if (c >= 'a' && c <= 'f') return c - 'a' + 10;
  if (c >= 'A' && c <= 'F') return c - 'A' + 10;
  return -1;
}

inline std::string urlDecode(const std::string& input)
{
  std::string result;

  for (size_t i = 0; i < input.size(); i++)
  {
    if (input[i] == '%' && i + 2 < input.size() && hexValue(input[i + 1]) >= 0 && hexValue(input[i + 2]) >= 0)
    {
      result.push_back(static_cast<char>((hexValue(input[i + 1]) << 4) | hexValue(input[i + 2])));
      i += 2;
    }
    else if (input[i] == '+')
    {
      result.push_back(' ');
    }
    else
    {
      result.push_back(input[i]);
    }
  }

  return result;
}

inline std::string htmlEscape(const std::string& input)
{
  std::string result;

  for (char c : input)
  {
    switch (c)
    {
      case '&': result += "&amp;"; break;
      case '<': result += "&lt;"; break;
      case '>': result += "&gt;"; break;
      case '"': result += "&quot;"; break;
      case '\'': result += "&#39;"; break;
      default: result.push_back(c);
    }
  }

  return result;
}

inline std::string sanitizeText(const std::string& input, size_t maxBytes)
{
  std::string result;

  for (unsigned char c : input)
  {
    if (c < 0x20 || c == 0x7F) continue;
    result.push_back(static_cast<char>(c));
  }

  if (result.size() > maxBytes)
  {
    size_t cut = maxBytes;

    while (cut > 0 && (static_cast<unsigned char>(result[cut]) & 0xC0) == 0x80) cut--;

    result.resize(cut);
  }

  size_t first = result.find_first_not_of(' ');

  if (first == std::string::npos) return std::string();

  size_t last = result.find_last_not_of(' ');

  return result.substr(first, last - first + 1);
}

inline std::string sha256Hex(const std::string& input)
{
  static const uint32_t k[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be,
    0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa,
    0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967, 0x27b70a85,
    0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070, 0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f,
    0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2};

  uint32_t h[8] = {0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19};

  std::string message = input;
  uint64_t bitLength = static_cast<uint64_t>(input.size()) * 8;

  message.push_back(static_cast<char>(0x80));

  while (message.size() % 64 != 56) message.push_back(0);

  for (int i = 7; i >= 0; i--) message.push_back(static_cast<char>((bitLength >> (i * 8)) & 0xFF));

  auto rotr = [](uint32_t x, int n) { return (x >> n) | (x << (32 - n)); };

  for (size_t offset = 0; offset < message.size(); offset += 64)
  {
    uint32_t w[64];

    for (int i = 0; i < 16; i++)
    {
      w[i] = (static_cast<uint32_t>(static_cast<unsigned char>(message[offset + i * 4])) << 24) |
             (static_cast<uint32_t>(static_cast<unsigned char>(message[offset + i * 4 + 1])) << 16) |
             (static_cast<uint32_t>(static_cast<unsigned char>(message[offset + i * 4 + 2])) << 8) |
             static_cast<uint32_t>(static_cast<unsigned char>(message[offset + i * 4 + 3]));
    }

    for (int i = 16; i < 64; i++)
    {
      uint32_t s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
      uint32_t s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
      w[i] = w[i - 16] + s0 + w[i - 7] + s1;
    }

    uint32_t a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7];

    for (int i = 0; i < 64; i++)
    {
      uint32_t s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
      uint32_t ch = (e & f) ^ (~e & g);
      uint32_t t1 = hh + s1 + ch + k[i] + w[i];
      uint32_t s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
      uint32_t maj = (a & b) ^ (a & c) ^ (b & c);
      uint32_t t2 = s0 + maj;

      hh = g;
      g = f;
      f = e;
      e = d + t1;
      d = c;
      c = b;
      b = a;
      a = t1 + t2;
    }

    h[0] += a;
    h[1] += b;
    h[2] += c;
    h[3] += d;
    h[4] += e;
    h[5] += f;
    h[6] += g;
    h[7] += hh;
  }

  char buffer[65];

  for (int i = 0; i < 8; i++) std::snprintf(buffer + i * 8, 9, "%08x", h[i]);

  return std::string(buffer, 64);
}
}
