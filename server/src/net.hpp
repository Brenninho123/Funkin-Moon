#pragma once

#include <cstdint>
#include <string>
#include <vector>

#ifdef _WIN32
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <winsock2.h>
#include <ws2tcpip.h>
#else
#include <arpa/inet.h>
#include <cerrno>
#include <fcntl.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <poll.h>
#include <signal.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>
#endif

namespace moon::net
{
#ifdef _WIN32
using Socket = SOCKET;
constexpr Socket InvalidSocket = INVALID_SOCKET;
using PollFd = WSAPOLLFD;
#else
using Socket = int;
constexpr Socket InvalidSocket = -1;
using PollFd = struct pollfd;
#endif

inline bool init()
{
#ifdef _WIN32
  WSADATA data;
  return WSAStartup(MAKEWORD(2, 2), &data) == 0;
#else
  signal(SIGPIPE, SIG_IGN);
  return true;
#endif
}

inline void shutdown()
{
#ifdef _WIN32
  WSACleanup();
#endif
}

inline void closeSocket(Socket socket)
{
#ifdef _WIN32
  closesocket(socket);
#else
  close(socket);
#endif
}

inline bool wouldBlock()
{
#ifdef _WIN32
  int error = WSAGetLastError();
  return error == WSAEWOULDBLOCK || error == WSAEINTR;
#else
  return errno == EWOULDBLOCK || errno == EAGAIN || errno == EINTR;
#endif
}

inline void setNonBlocking(Socket socket)
{
#ifdef _WIN32
  u_long mode = 1;
  ioctlsocket(socket, FIONBIO, &mode);
#else
  int flags = fcntl(socket, F_GETFL, 0);
  fcntl(socket, F_SETFL, flags | O_NONBLOCK);
#endif
}

inline void setNoDelay(Socket socket)
{
  int flag = 1;
  setsockopt(socket, IPPROTO_TCP, TCP_NODELAY, reinterpret_cast<const char*>(&flag), sizeof(flag));
}

inline Socket listenTcp(const std::string& address, uint16_t port, std::string& error)
{
  Socket listener = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);

  if (listener == InvalidSocket)
  {
    error = "could not create socket";
    return InvalidSocket;
  }

#ifndef _WIN32
  int reuse = 1;
  setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));
#endif

  sockaddr_in addr{};
  addr.sin_family = AF_INET;
  addr.sin_port = htons(port);

  if (inet_pton(AF_INET, address.c_str(), &addr.sin_addr) != 1)
  {
    error = "invalid bind address: " + address;
    closeSocket(listener);
    return InvalidSocket;
  }

  if (bind(listener, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) != 0)
  {
    error = "could not bind " + address + ":" + std::to_string(port);
    closeSocket(listener);
    return InvalidSocket;
  }

  if (listen(listener, 128) != 0)
  {
    error = "listen failed";
    closeSocket(listener);
    return InvalidSocket;
  }

  setNonBlocking(listener);

  return listener;
}

inline Socket acceptClient(Socket listener, std::string& remote)
{
  sockaddr_in addr{};
#ifdef _WIN32
  int length = sizeof(addr);
#else
  socklen_t length = sizeof(addr);
#endif

  Socket client = accept(listener, reinterpret_cast<sockaddr*>(&addr), &length);

  if (client == InvalidSocket) return InvalidSocket;

  char buffer[INET_ADDRSTRLEN] = {0};
  inet_ntop(AF_INET, &addr.sin_addr, buffer, sizeof(buffer));
  remote = buffer;

  setNonBlocking(client);
  setNoDelay(client);

  return client;
}

inline int sendSome(Socket socket, const char* data, size_t size)
{
#ifdef MSG_NOSIGNAL
  return static_cast<int>(send(socket, data, static_cast<int>(size), MSG_NOSIGNAL));
#else
  return static_cast<int>(send(socket, data, static_cast<int>(size), 0));
#endif
}

inline int receiveSome(Socket socket, char* data, size_t size)
{
  return static_cast<int>(recv(socket, data, static_cast<int>(size), 0));
}

inline int pollSockets(std::vector<PollFd>& fds, int timeoutMs)
{
#ifdef _WIN32
  if (fds.empty())
  {
    Sleep(timeoutMs);
    return 0;
  }

  return WSAPoll(fds.data(), static_cast<ULONG>(fds.size()), timeoutMs);
#else
  return poll(fds.data(), static_cast<nfds_t>(fds.size()), timeoutMs);
#endif
}
}
