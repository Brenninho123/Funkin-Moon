@echo off
setlocal

echo ===============================
echo   Funkin Mobile Build
echo ===============================
echo.

echo Installing HMM...
haxelib install hmm --quiet

echo.
echo Installing project dependencies (this may take a while)...
if exist .haxelib rmdir /s /q .haxelib
haxelib run hmm install
if errorlevel 1 goto ERROR

echo.
echo Building HXCPP tools...
for /f "delims=" %%i in ('haxelib libpath hxcpp') do set HXCPP_PATH=%%i
pushd "%HXCPP_PATH%tools\hxcpp"
haxe compile.hxml
popd
if errorlevel 1 goto ERROR

echo.
echo Rebuilding Lime (cpp)...
haxelib run lime rebuild cpp
if errorlevel 1 goto ERROR

echo.
echo   1. Android
echo   2. iOS
echo.
set /p choice="Choose a platform (1 or 2): "

if "%choice%"=="1" goto BUILD_ANDROID
if "%choice%"=="2" goto BUILD_IOS

echo Invalid choice.
goto END

:BUILD_ANDROID
echo.
echo Building for Android (arm64)...
haxelib run lime build android -arm64 -release
if errorlevel 1 goto ERROR
goto SUCCESS

:BUILD_IOS
echo.
echo Building for iOS...
echo NOTE: iOS builds require Xcode running on macOS. This will fail on Windows.
haxelib run lime build ios -release
if errorlevel 1 goto ERROR
goto SUCCESS

:ERROR
echo.
echo Build failed.
goto END

:SUCCESS
echo.
echo Build completed successfully.
goto END

:END
pause
