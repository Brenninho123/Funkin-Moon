cmake_minimum_required(VERSION 3.16)
project(moon-server CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(NOT CMAKE_BUILD_TYPE)
  set(CMAKE_BUILD_TYPE Release)
endif()

add_executable(moon-server src/main.cpp src/http_client.cpp)

find_package(Threads REQUIRED)
target_link_libraries(moon-server PRIVATE Threads::Threads)

if(WIN32)
  target_link_libraries(moon-server PRIVATE ws2_32 winhttp)
  target_compile_definitions(moon-server PRIVATE _CRT_SECURE_NO_WARNINGS)
else()
  find_package(CURL REQUIRED)
  target_link_libraries(moon-server PRIVATE CURL::libcurl)
endif()
