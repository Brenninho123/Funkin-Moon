@echo off
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%.."
set "PROJECT_ROOT=%CD%"
popd

if not exist "%PROJECT_ROOT%\Project.hxp" (
  echo Could not find Project.hxp in "%PROJECT_ROOT%".
  echo Make sure this script stays inside the project's "build" folder.
  pause
  exit /b 1
)

cd /d "%PROJECT_ROOT%"

echo ===============================
echo   Funkin Mobile Build
echo ===============================
echo   Project: %PROJECT_ROOT%
echo.

echo Installing HMM...
haxelib install hmm --quiet

set "HMM_HASH_FILE=.haxelib\.hmm-hash.txt"
set "NEED_INSTALL=1"

if exist ".haxelib" if exist "%HMM_HASH_FILE%" (
  for /f "usebackq delims=" %%h in (`certutil -hashfile hmm.json MD5 ^| find /v ":" ^| find /v " "`) do set "CURRENT_HASH=%%h"
  set /p STORED_HASH=<"%HMM_HASH_FILE%"
  if "!CURRENT_HASH!"=="!STORED_HASH!" set "NEED_INSTALL=0"
)

if "!NEED_INSTALL!"=="1" (
  echo.
  echo Dependencies changed or missing, reinstalling...
  if exist .haxelib rmdir /s /q .haxelib
  haxelib run hmm install
  if errorlevel 1 goto ERROR

  for /f "usebackq delims=" %%h in (`certutil -hashfile hmm.json MD5 ^| find /v ":" ^| find /v " "`) do echo %%h> "%HMM_HASH_FILE%"
) else (
  echo.
  echo Dependencies already up to date, skipping reinstall.
)

for /f "delims=" %%i in ('haxelib libpath hxcpp') do set "HXCPP_PATH=%%i"

if exist "%HXCPP_PATH%hxcpp.n" (
  echo.
  echo HXCPP tools already built, skipping.
) else (
  echo.
  echo Building HXCPP tools...
  pushd "%HXCPP_PATH%tools\hxcpp"
  haxe compile.hxml
  popd
  if errorlevel 1 goto ERROR
)

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
if not defined ANDROID_SDK_ROOT if not defined ANDROID_HOME (
  if exist "%LOCALAPPDATA%\Android\Sdk" (
    set "ANDROID_SDK_ROOT=%LOCALAPPDATA%\Android\Sdk"
    set "ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk"
    echo Detected Android SDK at "!ANDROID_SDK_ROOT!"
  ) else (
    echo Could not find an Android SDK. Set ANDROID_SDK_ROOT or ANDROID_HOME manually and run again.
    goto ERROR
  )
) else (
  if not defined ANDROID_SDK_ROOT set "ANDROID_SDK_ROOT=%ANDROID_HOME%"
  if not defined ANDROID_HOME set "ANDROID_HOME=%ANDROID_SDK_ROOT%"
  echo Using Android SDK at "!ANDROID_SDK_ROOT!"
)

set "NDK_ROOT="
if exist "%ANDROID_SDK_ROOT%\ndk" (
  for /f "delims=" %%n in ('dir /b /ad /o-n "%ANDROID_SDK_ROOT%\ndk" 2^>nul') do (
    if not defined NDK_ROOT set "NDK_ROOT=%ANDROID_SDK_ROOT%\ndk\%%n"
  )
)

if not defined NDK_ROOT (
  echo Could not find an installed Android NDK under "%ANDROID_SDK_ROOT%\ndk".
  echo Install one through Android Studio's SDK Manager and run again.
  goto ERROR
)

set "ANDROID_NDK_ROOT=%NDK_ROOT%"
echo Detected Android NDK at "!ANDROID_NDK_ROOT!"

echo.
echo Building for Android (arm64)...
haxelib run lime build android -arm64 -release
if errorlevel 1 goto ERROR
goto SUCCESS

:BUILD_IOS
echo.
echo iOS builds require Xcode running on macOS and cannot run from this Windows script.
echo Use the "ios" job in build.yml/release.yml on GitHub Actions, or run the build directly on a Mac.
goto END

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
