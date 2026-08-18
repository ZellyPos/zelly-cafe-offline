---
name: run-zelly-pos
description: Build, run, and drive the Zelly POS Windows desktop app. Use when asked to start Zelly, launch the POS app, run its tests, build the installer, take a screenshot of a screen, click through the UI, or verify a change in the real running app.
---

Zelly POS is a **Flutter Windows desktop** app (SQLite, offline-first).
There is no headless mode and no web build — it is driven by
`.claude/skills/run-zelly-pos/driver.ps1`, a PowerShell harness that
launches the built `.exe`, injects real Win32 mouse/keyboard input, and
captures screenshots.

All paths below are relative to the repo root.

> **Platform:** this only runs on Windows. There is no Linux/macOS path —
> the app targets `windows` and uses `win32`/`window_manager` plugins.
> Everything below was verified on Windows 11, PowerShell 5.1, Git Bash.

## Prerequisites

Flutter with Windows desktop enabled and Visual Studio C++ build tools:

```bash
flutter doctor            # "Visual Studio - develop Windows apps" must be ✓
flutter config --enable-windows-desktop
flutter pub get
```

For the installer only — Inno Setup 6 at
`C:\Program Files (x86)\Inno Setup 6\ISCC.exe`.

## Build

```bash
flutter build windows --release
```

Debug build also works (`--debug`) and the driver falls back to it, but
release starts faster and is what ships.

⚠️ **The driver launches the built `.exe`, not your source.** After
editing Dart you MUST rebuild, or you will screenshot the old UI and
conclude your change didn't work. This is the single easiest way to
waste an hour here.

## Run (agent path)

```bash
S=".claude/skills/run-zelly-pos/driver.ps1"
powershell -ExecutionPolicy Bypass -File $S launch
powershell -ExecutionPolicy Bypass -File $S shot /tmp/zelly.png
powershell -ExecutionPolicy Bypass -File $S quit
```

Commands (each call is independent — the window is re-resolved by PID,
no state is kept between calls):

| Command | Effect |
|---|---|
| `launch` | Starts the exe, waits up to 60s for a window. Prints `launched pid=N`. Idempotent — prints `already-running` if one is up. |
| `rect` | Window bounds as `Left Top Right Bottom`. Use before hardcoding coordinates. |
| `focus` | Brings the window forward. |
| `shot <file.png>` | Screenshot of the window region. Creates parent dirs. |
| `click <x> <y>` | Left click at screen coordinates. |
| `type <text>` | Types into the focused field (click it first). |
| `key <name>` | One key: `Escape`, `Enter`, `Tab`, `Backspace`. |
| `quit` | Kills all `tezzro.exe`. |

**Always look at the screenshot.** A blank or login-screen frame means
your navigation didn't land where you thought.

### Logging in

The app opens on a PIN pad. Read a valid PIN from the local database —
do not guess, and do not hardcode it into scripts:

```bash
dart run tool/db_query.dart "SELECT id, name, role, pin FROM users WHERE is_active = 1"
```

On a 1920×1080 fullscreen window the PIN pad keys are at:

```
1 (322,420)  2 (435,420)  3 (549,420)
4 (322,525)  5 (435,525)  6 (549,525)
7 (322,630)  8 (435,630)  9 (549,630)
C (322,735)  0 (435,735)  ⌫ (549,735)
```

Login happens automatically once the 4th digit is entered.

### Worked example — reach Ombor (inventory) and screenshot it

Verified end-to-end; this is the exact sequence used to check the
category TabBar work:

```bash
S=".claude/skills/run-zelly-pos/driver.ps1"
P() { powershell -ExecutionPolicy Bypass -File $S "$@"; }

P launch
for c in "322 420" "435 420" "549 420" "322 525"; do P click $c; done  # PIN 1234
P click 120 731     # sidebar: OMBOR (expands)
P click 120 774     # sidebar: Omborxona
P shot /tmp/ombor.png
```

Useful coordinates on the Ombor page (1920×1080):

| Target | Coords |
|---|---|
| Mahsulotlar / Xomashyolar tabs | `338 98` / `491 98` |
| Pishirish button (opens modal) | `645 98` |
| Search field | `900 164` |
| Category TabBar (first tab) | `297 217` |
| Category TabBar inside Pishirish modal | `693 350` |

## Direct invocation — read the database without the UI

Most inventory/report questions are answerable without launching
anything:

```bash
dart run tool/db_query.dart "SELECT name, category, quantity FROM products LIMIT 10"
dart run tool/db_query.dart "SELECT DISTINCT category FROM products ORDER BY category"
```

Read-only. Defaults to
`%APPDATA%/com.example/tezzro/tezzro_pos.db`; override with `ZELLY_DB`.

## Test

```bash
flutter analyze     # must be 0 errors; ~10 known warnings in cart_provider
flutter test        # 67 tests
```

Tests use `DatabaseHelper.databasePathOverride` with an in-memory DB —
they never touch the real database.

## Installer

```bash
"/c/Program Files (x86)/Inno Setup 6/ISCC.exe" zelly_installer.iss
```

Output: `C:\Users\<you>\Desktop\ZellySetup_<version>.exe`. Bump the
version in **three** places first, they must agree: `pubspec.yaml`,
`version.txt`, `zelly_installer.iss`.

## Run (human path)

`flutter run -d windows` — opens the window with hot reload. Useless for
an agent: it holds the terminal, its stdout is buffered so you cannot
detect readiness, and hot-reload keypresses need an interactive TTY.
Use the driver instead.

## Gotchas

**Naive clicks silently do nothing.** Setting the cursor and immediately
firing `mouse_event` down/up is ignored by Flutter's Windows embedder —
it routes a click to whatever widget last received a *hover* event. The
driver therefore walks the cursor toward the target in 5 steps, pauses
400 ms, and holds the button 350 ms. Removing any of those makes clicks
land on nothing, with no error.

**The window must be foregrounded before every input.** Synthetic input
to a background window is discarded. `click`/`type`/`key` all call
`SetForegroundWindow` first — do not "optimize" that away.

**Launching the raw build triggers the auto-updater.** The app reads its
version from `version.txt` *next to the exe*; the build folder has none,
the CWD has no `pubspec.yaml` either, so it falls back to `1.0.0`,
decides it is outdated, and starts downloading + installing a real
update over your machine. The driver copies `version.txt` into the build
folder before launching. If you launch the exe by hand, copy it yourself.

**`.ps1` files must be saved UTF-8 *with BOM*.** PowerShell 5.1 reads
BOM-less UTF-8 as ANSI; the Uzbek text in comments then mangles into
bytes that break string parsing, and you get a wall of
`Unexpected token '{'` errors pointing at lines that are fine. If you
edit `driver.ps1` with a tool that strips the BOM, restore it:

```powershell
$p = ".claude\skills\run-zelly-pos\driver.ps1"
$c = [IO.File]::ReadAllText($p, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText($p, $c, (New-Object Text.UTF8Encoding($true)))
```

**Screenshots come from the screen, not the window.** Flutter renders
via GPU, so `PrintWindow` returns an empty frame. The driver uses
`CopyFromScreen` over the window rect — which means **the window must be
unobscured**. Anything on top of it (an IDE, a notification toast) lands
in your screenshot.

**Coordinates assume a 1920×1080 fullscreen window.** Run `rect` first
and scale if the window differs.

**`flutter run` output is unusable for readiness detection.** It buffers,
so the log file stays empty for minutes. Poll for the process/window
instead — which is what `launch` does.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `Build topilmadi` | No exe yet: `flutter build windows --release` |
| `Ilova oynasi topilmadi` | Not running, or still starting. `launch` first; first start can take ~10s (license check + SQLite migrations). |
| Clicks do nothing, no error | Window not focused, or you bypassed the driver's hover walk. Use `click`, not raw `mouse_event`. |
| A "Yangi versiya mavjud!" dialog appears | `version.txt` missing beside the exe — see Gotchas. `quit`, re-`launch` via the driver. |
| `Unexpected token '{'` from driver.ps1 | Lost UTF-8 BOM — see Gotchas. |
| Screenshot shows the IDE | Another window is on top. `focus`, then `shot`. |
| `Baza topilmadi` from `db_query.dart` | App has never run on this machine; `launch` once to create the DB. |
