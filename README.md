# Area Incident Tracker — Flutter Desktop (Windows)

Flutter port of the ASP.NET Core website. Same live API (`http://areatrackerapi.runasp.net/`), same pages,
same Compass light/dark theme, same flows. `web_icon.png` is the exe/window icon and the brand logo.

## Run
1. Install Flutter (stable, Dart >= 3.3) + Visual Studio "Desktop development with C++".
2. In this folder: `setup_windows.bat` (one time), then `flutter run -d windows`.
3. Release: `flutter build windows --release`.

## Keyboard
Press **F1** (or **?**) in the app for the full list.
Ctrl+1..5 pages · Ctrl+K place picker · Ctrl+N new · Ctrl+S save / save PDF · Ctrl+P print ·
Ctrl+Shift+P save PDF · Ctrl+H history · Ctrl+F or / search · Ctrl+T theme · Ctrl+R/F5 reload ·
Ctrl+Shift+Q log out · Esc / Alt+Left back · F11 full screen · Places list: arrows, Enter, E, Delete, PageUp/PageDown ·
Sliders: arrows or 1-9/0 · Calendar: arrows, PageUp/Down, Home, Enter · Framework: 0-4 · Map: arrows, +/-, Home.

## Notes
- Map tiles and place geocoding use OpenStreetMap / Nominatim (internet required), cached locally like the site.
- Printing uses the Windows print dialog; "Save PDF" writes a file. First build downloads the PDFium binary.
- UI font is Arial like the site's final stylesheet; Inter is bundled only for the PDF report.
