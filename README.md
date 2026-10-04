# Area Incident Tracker — Desktop

A Flutter desktop client (Windows) for the **Area Incident Tracker** platform: a place-based
11-domain life/area assessment tool used to score Philippine localities, track them over time,
and publish printable "Personal Life Audit" reports.

This app is a port of the original ASP.NET Core website. It talks to the **same live API**,
reproduces the **same pages and flows**, and carries the same green Compass design language
in both **light and dark** themes.

| | |
|---|---|
| Package name | `area_incident_tracker` |
| Version | `1.0.0+1` |
| Platform | Windows desktop (Win32 + Flutter engine) |
| Backend | `http://areatrackerapi.runasp.net/` (ASP.NET Core, JWT bearer auth) |
| Dart SDK | `>=3.3.0 <4.0.0` |
| Product icon | `assets/images/web_icon.png` (also the window/`.exe` icon) |

---

## Table of contents

- [Features](#features)
- [Requirements](#requirements)
- [Getting started](#getting-started)
- [Building](#building)
- [Project structure](#project-structure)
- [Architecture](#architecture)
- [Backend API reference](#backend-api-reference)
- [Data model](#data-model)
- [Keyboard shortcuts](#keyboard-shortcuts)
- [External services & connectivity](#external-services--connectivity)
- [Design system](#design-system)
- [Assets & fonts](#assets--fonts)
- [Development workflow](#development-workflow)
- [Troubleshooting](#troubleshooting)

---

## Features

### 1. Sign in (`lib/pages/login_page.dart`)
Username/password sign-in against the live API, with a **Keep me signed in** option and an
inline validation summary. Shows the brand icon and the current Compass theme.

### 2. Dashboard (`lib/pages/dashboard_page.dart`)
The live scoreboard for the selected place.
- Five stat tiles: overall score, status, priority, weakest domain, strongest domain.
- Per-domain breakdown bars and a score-band distribution bar chart.
- A **category compass** — an 11-axis radar drawn with `CustomPaint`.
- Guidance card generated from the domain assessment framework.
- Staggered entrance animations.

### 3. Places (`lib/pages/places_page.dart`)
Full CRUD over the place catalogue.
- Search by name or PSGC code, filter by administrative level, filter by parent place.
- Server-side pagination (page size 15).
- **Create / edit** form with PSGC code, name, level, parent, income class, city/municipality
  type, capital flag, urban/rural, old name, client GUID.
- **Delete** with confirmation.
- Fully keyboard driven row selection (see [Keyboard shortcuts](#keyboard-shortcuts)).

### 4. Area Map (`lib/pages/area_map_page.dart`)
An interactive map of the Philippines with status-coloured pins for every place.
- OpenStreetMap raster tiles + marker clustering.
- Search by name/PSGC; toggle to include unassessed places.
- Hover cards with score, status, priority, weakest/strongest domain.
- Places are geocoded via Nominatim and the coordinates are cached locally, so previously
  visited places still plot while offline.
- Keyboard panning, zooming and recentring.

### 5. New Assessment (`lib/pages/assessment_page.dart`)
The data-entry form that drives everything else.
- 11 domain sliders (1–10) with a red → orange → gold → teal gradient track.
- **North Star statement**, three **top priorities**, and a **stop / reduce** field.
- Assessment date, next review date, review frequency (Monthly / Quarterly), notes.
- Overall score, status, priority, weakest and strongest domains are computed and echoed back
  from the API on save.

### 6. History (`lib/pages/history_page.dart`)
Every assessment recorded for a place, over time.
- Animated spline **trend chart** (Chart.js-style interpolation) of the overall score with a
  hover tooltip.
- Sortable table of past assessments; per-row print action.

### 7. Print Report (`lib/pages/report_page.dart`) + PDF (`lib/services/report_pdf.dart`)
- On-screen report preview.
- **Print** via the native Windows print dialog (`printing` package layout).
- **Save as PDF** via a native save dialog (`file_selector`), producing
  `Life Audit Report - <place> - <date>.pdf`.
- A4, 2 cm margins. Contents: header with status/date pills, stat row, place identity block,
  the 4-band rating scale guide, the 11-domain score table, automated insights, the direction
  section (North Star + priorities + stop/reduce), and a footer disclaimer.

### 8. Domain Assessment Framework (`lib/pages/framework_page.dart`)
The reference guide that explains what each score means, straight from
`assets/domain_assessment_framework.json`.
- Search box, level filter chips, expandable advice cards per domain.

### 9. Shell & navigation (`lib/widgets/shell.dart`, `lib/app.dart`)
- Right-hand **sidebar** on wide windows (brand, 5 nav entries, theme toggle, user, log out).
  Switches to a hamburger + slide-over overlay below 900 px.
- Window title tracks the current route: `<Page> — Area Incident Tracker - Database - Web`.
- Light/dark theme toggle persisted across launches.

---

## Requirements

| Requirement | Notes |
|---|---|
| **Flutter stable** | Dart `>=3.3.0`. Windows desktop support enabled via `flutter config --enable-windows-desktop`. |
| **Visual Studio 2022** | With the **"Desktop development with C++"** workload — required to compile the Win32 runner. |
| **Windows 10/11** | x64. |
| **Internet access** | Needed for the API, the OpenStreetMap tile server and Nominatim geocoding. |

---

## Getting started

### One-time setup

```bat
setup_windows.bat
```

The script (in order):
1. Verifies `flutter` is on `PATH`.
2. Enables the Windows desktop platform.
3. Runs `flutter create --platforms=windows --project-name area_incident_tracker --org com.areaincidenttracker .`
   to generate the `windows/` runner.
4. Copies `assets\icon\app_icon.ico` over `windows\runner\resources\app_icon.ico`.
5. Runs `flutter pub get`.

### Run

```bat
flutter pub get
flutter run -d windows
```

The window opens at **1440 × 900** (minimum **480 × 560**), centred on screen.

---

## Building

```bat
flutter build windows --release
```

Output: `build\windows\x64\runner\Release\`

The release folder is self-contained — copy the whole `Release` directory to any Windows x64
machine to distribute the app. The first build downloads the **PDFium** binary used by the
`printing` package for print/PDF rendering.

Other useful targets:

```bat
flutter run -d windows --profile        # profile build with DevTools
flutter build windows --release --obfuscate --split-debug-info=build/symbols
```

---

## Project structure

```
aitf/
├── analysis_options.yaml          # flutter_lints base + 4 rules relaxed for this codebase
├── pubspec.yaml                   # name, deps, assets, ReportSans font family
├── setup_windows.bat              # one-time Windows runner + icon + pub get setup
├── assets/
│   ├── domain_assessment_framework.json   # 4 levels × 11 domains of guidance
│   ├── fonts/
│   │   ├── Inter-Regular.ttf              # PDF report body text
│   │   └── Inter-Bold.ttf                 # PDF report headings (weight 700)
│   ├── icon/
│   │   ├── app_icon.ico                   # Windows .exe / window icon source
│   │   └── app_icon.png                   # PNG icon source
│   └── images/
│       └── web_icon.png                   # brand logo shown in-app (login + sidebar)
├── lib/
│   ├── main.dart                  # bootstrap, window_manager setup
│   ├── app.dart                   # MaterialApp, global shortcuts, page router, root focus
│   ├── models/
│   │   └── models.dart            # DTOs, 11 domain constants, date/number formatters
│   ├── pages/                     # one file per screen (8 pages)
│   ├── services/
│   │   ├── api_client.dart        # HTTP, bearer auth, silent refresh, request cache
│   │   ├── geocoder.dart          # Nominatim lookup + persistent coordinate cache
│   │   ├── report_pdf.dart        # PDF builder for the audit report
│   │   └── session_store.dart     # token persistence in SharedPreferences
│   ├── state/
│   │   └── app_state.dart         # ChangeNotifier: route, history, toasts, modals
│   ├── theme/
│   │   ├── palette.dart           # AppPalette ThemeExtension, score-band colours
│   │   └── theme.dart             # Material 3 ThemeData, Arial type scale
│   └── widgets/
│       ├── anim.dart              # stagger(), Entrance, LoadingBlock
│       ├── common.dart            # layout + form primitives (LaCard, LaButton, …)
│       ├── help_dialog.dart       # F1 shortcut reference
│       ├── icons.dart             # inline SVG icon set (13 UI + 11 domain icons)
│       ├── modal.dart             # LaModal, laConfirm, laAlert
│       ├── pickers.dart           # place picker + keyboard date picker
│       ├── shell.dart             # sidebar, mobile top bar, page frame
│       └── toast.dart             # ToastHost / ToastCard
├── test/
│   └── widget_test.dart           # see "Testing" below
└── windows/                       # generated Win32 runner (CMake + C++)
    ├── CMakeLists.txt
    ├── flutter/                   # generated_plugin_registrant.* , generated_plugins.cmake
    └── runner/                    # main.cpp, flutter_window.cpp, win32_window.cpp, Runner.rc, app_icon.ico
```

### The design vocabulary

Widgets are prefixed `La*` (`LaCard`, `LaButton`, `LaInput`, `LaModal`, `LaSelect`,
`LaCheckbox`, `LaBadge`, `LaStat`, `LaLabel`, `LaGrid`, `TopBar`, `LinkText`) and are themed
exclusively through `AppPalette`, so light and dark stay in sync from one token set.

---

## Architecture

### State management

A hand-rolled `ChangeNotifier` — **no** Provider/Bloc/Riverpod. `AppState`
(`lib/state/app_state.dart`) is created once in `main()` and injected into the widget tree;
`app.dart` rebuilds the authenticated shell on every `notifyListeners()`.

`AppState` owns:

| Member | Purpose |
|---|---|
| `prefs`, `session`, `api`, `geocoder` | Initialised in `init()` |
| `darkMode` (`ValueNotifier<bool>`) | Drives `MaterialApp.themeMode`; persisted |
| `toasts` (`ValueNotifier<List<ToastData>>`) | Toast queue |
| `route` (`AppRoute`) | Current page + parameters |
| `history` (`List<AppRoute>`) | Manual back stack, capped at 60 entries |
| `modalDepth`, `helpOpen`, `sidebarOpen` | Overlay bookkeeping |
| `mainFocus` (`FocusNode`) | Global keyboard focus target |
| `pageActions` (`PageActions?`) | Current page's shortcut callbacks |
| `requestLogout` | Lets the sidebar reuse the root's logout confirm flow |
| `contextPlaceId` | The place shared across dashboard / history / report |

### Routing

`enum PageId { login, dashboard, places, placeCreate, placeEdit, assessmentNew, history,
report, framework, areaMap }` with an `AppRoute` carrying `placeId`, `id`, `search`, `level`,
`parentPlaceId` and `pageNo`. Navigation is a single switch in `app.dart`; there is no
`go_router` / Navigator 2.0. Each route exposes `title` (for the window title) and
`navHighlight` (which sidebar entry stays active — e.g. both *New Assessment* and *History*
highlight the *New Assessment* entry).

`navigate()` pushes the previous route onto `history`; `back()` pops it, falling back to the
Dashboard; `reload()` rebuilds the current route with the same parameters (this is what
`Ctrl+R` / `F5` and re-clicking the active nav entry do).

### Keyboard focus model

`_Root` in `lib/app.dart` owns three layers:
1. `Shortcuts` / `Actions` maps for all `Ctrl`/`F` key combinations.
2. A raw `onKeyEvent` handler for plain characters (`/`, `?`, digits) that must not fire
   while typing.
3. A rebuild hook that parks focus on `app.mainFocus` whenever no modal is open — this is why
   global shortcuts keep working after interacting with a page.

Each page registers a `PageActions` record (`focusSearch`, `save`, `print`, `savePdf`,
`openHistory`, `newItem`, `placePicked`) so global shortcuts can reach page-specific handlers
without the global scope knowing which page is mounted.

### Error handling

- **API layer:** never throws. `get()` returns `null` on any failure; `post()` returns
  `(success, body, errorMessage)`; `put()`/`delete()` return `bool`. All requests time out at
  **30 s**.
- **Auth:** when a refresh is rejected (401/400/403) `onSessionExpired` fires and the app
  signs out locally and returns to Sign in.
- **UI:** forms collect messages into a `List<String>` rendered by `ValidationSummary`;
  everything else surfaces as a toast (`success` / `error` / `warning` / `info` / `question`,
  4.2 s default, pauses on hover).

---

## Backend API reference

Base URL: **`http://areatrackerapi.runasp.net/`** (`ApiClient.baseUrl`, `lib/services/api_client.dart:19`).

| Method | Path | Used by |
|---|---|---|
| `POST` | `api/auth/login` | Sign in. Body: `username`, `password`, `deviceInfo: "Website"` |
| `POST` | `api/auth/refresh` | Silent token refresh. Body: `refreshToken`, `deviceInfo: "Website"` |
| `POST` | `api/auth/logout` | Log out (posts the refresh token) |
| `GET` | `api/places` | Places list & map. Supports paging, `search`, `level`, `parentPlaceId` |
| `GET` | `api/places/{id}` | Single place (cached 5 min) |
| `POST` | `api/places` | Create a place |
| `PUT` | `api/places/{id}` | Update a place |
| `DELETE` | `api/places/{id}` | Delete a place |
| `GET` | `api/assessments` | All assessments (cached 60 s) — feeds the map |
| `GET` | `api/assessments?placeId={id}` | Assessment history for a place |
| `GET` | `api/assessments/latest/{placeId}` | Latest assessment (dashboard, report) |
| `POST` | `api/assessments` | Create an assessment |

### Authentication flow

1. `login` returns an access token, a long-lived refresh token, and the absolute access-token
   expiry.
2. Every request carries `Authorization: Bearer <access token>`.
3. Before each request the client checks the expiry with a **30 s safety buffer**; if it is
   expired (or about to be) it refreshes once — **single-flight**, so concurrent requests share
   a single refresh call rather than racing.
4. A rejected refresh triggers a full local sign-out.

### Caching

`ApiClient` keeps a short-lived in-memory `Map<String, _CacheEntry>`:
`api/places/{id}` for 5 minutes, `api/assessments` for 60 seconds. Any mutation that touches
`api/places` or `api/assessments` bulk-invalidates the matching cache entries.

### Session persistence

`SessionStore` (`lib/services/session_store.dart`) writes to `SharedPreferences` under:

| Key | Value |
|---|---|
| `auth.access` | Access token |
| `auth.refresh` | Refresh token |
| `auth.expires` | Access-token expiry (ISO 8601) |
| `auth.username` | Username |
| `auth.display` | Display name |
| `auth.role` | Role |
| `auth.savedAt` | Timestamp used for the **sliding 60-day expiry** |

Tokens are only written to disk when **Keep me signed in** is checked; otherwise signing in
wipes the auth keys so the session ends with the app. On load, a session older than 60 days is
discarded.

---

## Data model

### The 11 assessment domains

Every assessment scores exactly these, in this order (`kDomainFields` / `kDomainLabels` in
`lib/models/models.dart`):

| # | Field key | Label |
|---|---|---|
| 1 | `spiritual` | Spiritual |
| 2 | `family` | Family |
| 3 | `health` | Health |
| 4 | `financial` | Financial |
| 5 | `intellectual` | Intellectual |
| 6 | `leadership` | Leadership |
| 7 | `ministry` | Ministry |
| 8 | `organization` | Organization |
| 9 | `community` | Community |
| 10 | `nationalContribution` | National Contribution |
| 11 | `internationalEngagement` | International Engagement |

### Score bands

| Score | Band | Colour | Hex |
|---|---|---|---|
| 8 – 10 | green | green | `#3FBF9F` |
| 5 – 7 | yellow | yellow | `#F2C94C` |
| 3 – 4 | orange | orange | `#F2994A` |
| 1 – 2 | red | red | `#E5484D` |

Overall status: `THRIVING` → green, `BALANCING` → yellow, `STRUGGLING` → orange, anything
else → red. Priority: `URGENT` → red, `HIGH` / `MODERATE` → orange, `MAINTAIN` → green,
unknown → transparent.

### Key models

- **`AuthResponse`** — `accessToken`, `refreshToken`, `accessTokenExpiresAt`, `username`,
  `displayName`, `role`.
- **`PlaceDto`** — `placeId`, `psgcCode`, `name`, `level`, `parentPlaceId`, `incomeClass`,
  `cityType`, `isCapital`, `urbanRural`, `oldName`, `clientGuid`.
- **`PlaceUpsert`** — the mutable form of the above with `toJson()`; the POST/PUT payload.
- **`PagedResult<T>`** — `items`, `totalCount`, `page`, `pageSize`.
- **`AssessmentDto`** — `assessmentId`, `placeId`, `placeName`, `psgcCode`, `assessmentDate`,
  `scores` (11 ints), `overallScore`, `overallStatus`, `weakestDomain`, `weakestScore`,
  `strongestDomain`, `strongestScore`, `priorityLevel`, `automatedAdvice`,
  `northStarStatement`, `topPriority1..3`, `stopReduce`, `nextReviewDate`, `reviewFrequency`,
  `notes`.
- **`AssessmentUpsert`** — `placeId`, `assessmentDate`, `scores` (11 ints, default 5),
  `northStarStatement`, `topPriority1..3`, `stopReduce`, `nextReviewDate`, `reviewFrequency`
  (default `Monthly`), `notes`; plus `clientGuid: null`.
- **`FrameworkData` / `FrameworkDomainAdvice`** — parsed from
  `assets/domain_assessment_framework.json`.
- **`AreaMapPoint`** — the flattened map-pin projection: place identity, geocode query, latest
  score/status/priority/weakest/strongest, last assessment date, and resolved `lat` / `lng`.

### Framework levels

`assets/domain_assessment_framework.json` holds 4 score levels
(`critical_1_2`, `struggling_3_4`, `balancing_5_7`, `thriving_8_10`) and one advice entry per
domain per level — 44 guidance strings total. The Framework page filters by these levels.

### Formatters

`models.dart` centralises all date/number rendering: `parseUtc`, `parseLocalDate`, `ymd`
(`yyyy-MM-dd`), `fmtMmmDYyyy` (`Jan 5, 2026`), `fmtMmmmDYyyy` (`January 5, 2026`),
`fmtMmmYyyy` (`Jan 2026`), `monthName`, `numText` (drops a trailing `.0`), and `shortDomain`
for the compact chart labels (`Spirit`, `Fin`, `Intel`, `Lead`, `Min`, `Org`, `Comm`,
`Nation`, `Intl`).

---

## Keyboard shortcuts

Press **F1** (or **?**) inside the app for this same list.

### Navigate

| Shortcut | Action |
|---|---|
| `Ctrl + 1` … `Ctrl + 5` | Dashboard · Places · Area Map · New Assessment · Assessment Framework |
| `Esc` / `Alt + ←` | Go back (closes dialogs first) |
| `Ctrl + B` | Show / hide the menu (narrow windows) |
| `Ctrl + R` / `F5` | Reload the current page |

### Actions

| Shortcut | Action |
|---|---|
| `Ctrl + K` | Pick a place (opens the Dashboard for it) |
| `Ctrl + N` | New item for this page (Add Place / New Assessment) |
| `Ctrl + S` | Save the form / Save report as PDF |
| `Ctrl + P` | Print the report |
| `Ctrl + Shift + P` | Save the report as PDF |
| `Ctrl + H` | History for the current place |
| `Ctrl + F` / `/` | Focus the search box |
| `Ctrl + T` | Switch light / dark theme |
| `Ctrl + Shift + Q` | Log out |
| `F11` | Full screen |
| `F1` / `?` | Show the shortcut help |

> `Ctrl + 1..5` also work with the numeric keypad.

### Places list

| Shortcut | Action |
|---|---|
| `↑` `↓` `Home` `End` | Move the row selection |
| `Enter` | Open the Dashboard for the selected place |
| `E` | Edit the selected place |
| `Delete` | Delete the selected place |
| `Page Up` / `Page Down` | Previous / next page of results |

### Forms

| Shortcut | Action |
|---|---|
| `Tab` / `Shift + Tab` | Next / previous field |
| `←` `→` on a slider | Change a score by 1 |
| `1`–`9`, `0` on a slider | Jump to that score (`0` = 10) |
| `Enter` / `Space` on a date field | Open the calendar |

### Calendar & place picker

| Shortcut | Action |
|---|---|
| Arrow keys | Move the day / the highlighted place |
| `Page Up` / `Page Down` | Previous / next month (place picker: page by 6) |
| `Home` | Jump to today |
| `Enter` | Choose |
| `Esc` | Close |

### Framework page

| Shortcut | Action |
|---|---|
| `0` – `4` | All levels / each score level |
| `Enter` / `Space` | Expand or collapse guidance |

### Area Map (click the map first)

| Shortcut | Action |
|---|---|
| Arrow keys | Pan (hold `Shift` to pan faster) |
| `+` / `−` | Zoom in / out |
| `Home` | Recentre on the Philippines |

---

## External services & connectivity

| Service | Endpoint | Purpose | Notes |
|---|---|---|---|
| Area Tracker API | `http://areatrackerapi.runasp.net/` | All data | Bearer JWT |
| OpenStreetMap tiles | `https://tile.openstreetmap.org/{z}/{x}/{y}.png` | Base map | Attribution shown in-app |
| Nominatim | `https://nominatim.openstreetmap.org/search` | Place geocoding | `format=json`, `limit=1`, `countrycodes=ph` |

The geocoder identifies itself as `AreaIncidentTracker-Desktop/1.0 (Flutter Windows)` and
**throttles to one request per 1100 ms** to comply with the Nominatim usage policy.

**Offline behaviour.** There is no offline mode or request queue. If the API is unreachable,
list views fall back to their empty/loading states and the map shows only places whose
coordinates are already in the local geocode cache. That cache is written to
`SharedPreferences` under `la-area-map-geocode-cache-v1` (flushed every 5 new entries) and
survives restarts, so the map gets progressively better the more you use it.

---

## Design system

The palette is a Flutter `ThemeExtension` (`AppPalette` in `lib/theme/palette.dart`), so any
widget can read `context.pal` and get light or dark tokens without conditionals.

| Token | Light | Dark | Use |
|---|---|---|---|
| `ink900` | `#E7F0E9` | `#06150C` | Deepest surface |
| `ink800` | `#F5F9F5` | `#0A2113` | App background / scaffold |
| `ink700` | `#FFFFFF` | `#10351F` | Card surface |
| `ink600` | `#DCEBE0` | `#174A2B` | Inputs, inner panels, chips |
| `ink500` | `#A9C5B0` | `#2B6942` | Accent borders |
| `line` | `rgba(18,76,43,.18)` | `rgba(190,230,201,.18)` | Hairline dividers |
| `textHi` | `#123C25` | `#EFF9F0` | Primary text |
| `textMid` | `#3E624B` | `#B9D7BF` | Body text |
| `textLow` | `#68836F` | `#80AA8A` | Captions, hints |
| `gold` | `#2F8B57` | `#72C58C` | Secondary accent / links |
| `goldDim` | `#1E6840` | `#459765` | Hover state |
| `teal` | `#176B3C` | `#9ADB9F` | Primary accent |

Helpers: `bandColor(score)`, `bandName(score)`, `statusColor(status)`, `priorityColor(p)`.

`lib/theme/theme.dart` builds Material 3 `ThemeData` from the palette (`primary: teal`,
`secondary: gold`), and adds a custom text scale via `ts(context, size:, weight:, color:,
spacing:)` — 15 px / `w400` / `textMid` / 1.55 line-height by default.

**Typography.** The UI uses **Arial** (`kFont`, falling back to Segoe UI → Segoe UI Emoji →
Segoe UI Symbol) to match the website's final stylesheet. **Inter** is bundled *only* for the
PDF report, where a Unicode-safe font is required. Shortcut keys render in Consolas.

---

## Assets & fonts

| Path | Purpose |
|---|---|
| `assets/images/web_icon.png` | Brand logo — login page (120 px) and sidebar (36 px) |
| `assets/icon/app_icon.ico` | Windows `.exe` / window icon, copied into the runner by `setup_windows.bat` |
| `assets/icon/app_icon.png` | PNG source for the icon above |
| `assets/domain_assessment_framework.json` | 4 levels × 11 domains of guidance (6.3 KB) |
| `assets/fonts/Inter-Regular.ttf` | PDF report body (`ReportSans`) |
| `assets/fonts/Inter-Bold.ttf` | PDF report headings (`ReportSans`, weight 700) |

Declared in `pubspec.yaml` under `flutter: assets:` and `flutter: fonts:`. Adding a new asset
requires both a `pubspec.yaml` entry and a `flutter pub get`.

---

## Development workflow

```bat
flutter pub get                # fetch packages
flutter run -d windows         # run with hot reload (r), hot restart (R)
flutter analyze                # static analysis
dart format --line-length 100 lib test
flutter build windows --release
```

### Lint configuration

`analysis_options.yaml` includes `package:flutter_lints/flutter.yaml` and relaxes four rules
for this codebase: `prefer_const_constructors`, `prefer_const_literals_to_create_immutables`,
`avoid_print`, and `deprecated_member_use`.

### Testing

`flutter test` **currently fails**: `test/widget_test.dart` is the untouched Flutter template
test and references a `MyApp` class that does not exist in this project
(`error - The name 'MyApp' isn't a class`, `test/widget_test.dart:16`). Replace it with a real
test before relying on the suite. There is no other test coverage today — the models, API
client, and formatters are all pure functions and are the natural place to start.

`flutter analyze` currently reports 19 issues: 1 error (the test above), 6 warnings
(an unused field and unused imports/locals, plus an unrecognised lint rule name in
`analysis_options.yaml`), and 12 deprecation infos from `withOpacity`/`opacity` on this
Flutter version.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `flutter` not recognised | Install Flutter and add `flutter\bin` to `PATH`. |
| Build fails with an MSBuild/CMake error | Install Visual Studio 2022 with the **Desktop development with C++** workload. |
| `MissingPluginException` / no window opens | Run `setup_windows.bat` once to generate the runner and plugin registrant. |
| `PlatformException` when printing | First build downloads the PDFium binary — allow it to finish, then retry. |
| Map is blank | Check internet access (OSM tiles) and that the place has been geocoded before. |
| Sign-in fails immediately | The API is plain HTTP; a proxy or an offline machine will block `areatrackerapi.runasp.net`. |
| Session lost between runs | Expected unless **Keep me signed in** was checked (and within the 60-day window). |