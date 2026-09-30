@echo off
setlocal
if not exist build mkdir build
cl /nologo /std:c++17 /EHsc /O2 /W3 /D_CRT_SECURE_NO_WARNINGS /Fo:build\ /Fe:build\moon-server.exe src\main.cpp src\http_client.cpp ws2_32.lib winhttp.lib
endlocal
