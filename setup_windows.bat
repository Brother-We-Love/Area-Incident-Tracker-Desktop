@echo off
REM One-time setup: generates the Windows runner, applies web_icon.png as the .exe/window icon, fetches packages.
where flutter >nul 2>nul || (echo Flutter SDK not found on PATH. Install from https://docs.flutter.dev/get-started/install/windows & exit /b 1)
call flutter config --enable-windows-desktop
call flutter create --platforms=windows --project-name area_incident_tracker --org com.areaincidenttracker .
copy /Y assets\icon\app_icon.ico windows\runner\resources\app_icon.ico
call flutter pub get
echo.
echo Done. Run with:   flutter run -d windows
echo Release build:    flutter build windows --release
echo Output folder:    build\windows\x64\runner\Release\
