@echo off
setlocal

echo ===============================
echo   Funkin Mobile Build
echo ===============================
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
