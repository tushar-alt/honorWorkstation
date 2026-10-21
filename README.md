# HONOR WorkStation Fix

Make **HONOR WorkStation (Hihonornote)** work on any Windows PC — including non-HONOR laptops (that's you if you saw *"this app is not allowed to run on this device"*).

## What this repo contains

| File | Purpose |
|---|---|
| `Fix-HonorWorkStation.bat` | One-click fix: repairs the app and launches it |
| `README.md` | This guide |

> **The installer (`HonorWorkStation_Setup_3IN1_*.exe`, ~1 GB) is NOT included here** — GitHub doesn't allow files that big. Grab the official installer from HONOR's downloads, or use the shared zip where you got this file from. If an installer file is placed **in the same folder** as the bat, the script can install the app for you too.

## How to use (non-technical version)

1. Put `Fix-HonorWorkStation.bat` (and the Setup exe, if you have it) in any folder.
2. Double-click **Fix-HonorWorkStation.bat**.
3. When Windows asks *"Do you want to allow this app to make changes?"* → click **Yes** (there may be 1–3 of these; click Yes on all).
4. Wait — it fixes things by itself and opens the app.
5. You'll see **Done** when it works; it also saves a log at `%TEMP%\HonorWorkStation_fix.log` (useful if you need support).

No admin rights needed for the common case — only the standard UAC click when the script must install or when the device identity needs fixing.

## What it actually does (technical details)

Root causes found by reading the app's own logs (Electron app):

1. **Device identity check** — the app reads `HKLM\SOFTWARE\HONOR` and refuses to run on non-HONOR hardware ("not allowed to run on this device").
2. **Missing feature flags** — at startup it queries the OfficeCenter IPC backbone for a JSON feature list. Missing/broken backend → empty response → `JSON.parse` throws → the app **exits itself with code 1019** (`GET_FEATURES_ERROR`). The designed fallback file `%USERPROFILE%\.config\hihonornote\features.json` is usually missing too → silent crash loop, no window ever.

The bat handles all of it:

- Detects a missing install and silently runs the bundled 3IN1 installer (`/S`) if it's sitting next to the bat.
- Writes the two device-identity registry keys (self-elevates once if needed):
  - `HKLM\SOFTWARE\HONOR\HonorVersion\HonorDevice = 1`
  - `HKLM\SOFTWARE\HONOR\BIOS\ProductVersion = HONOR`
- Creates `%USERPROFILE%\.config\hihonornote\features.json` (plain UTF-8, no BOM — a BOM breaks the app's parser) with the app's own default flags:
  - `{"DistributedFramework":"1","HonorFileShare":"1","NetworkSharing":"1","SuperHandoff":"1","SuperKeyMouse":"1","SuperNotification":"1","SuperTerminal":"1","VirtualDeviceService":"1"}`
- Warns if the OfficeCenter component is missing (share/phone-connect features degraded) or the install looks modified (`app.asar.honor-compat-backup` present).
- Launches the app, then verifies after ~6 s and again after ~21 s that it's still alive, and reports PASS/FAIL with a saved log. Already-running installs just get "already running, nothing to do".
- It is idempotent: existing valid `features.json` is left untouched; re-running is always safe.

## Manual fix (for DIY people)

```
elevated cmd:
reg add "HKLM\SOFTWARE\HONOR\HonorVersion" /v HonorDevice /t REG_SZ /d 1 /f
reg add "HKLM\SOFTWARE\HONOR\BIOS" /v ProductVersion /t REG_SZ /d HONOR /f

create %USERPROFILE%\.config\hihonornote\features.json  (UTF-8 WITHOUT BOM!)
{"DistributedFramework":"1","HonorFileShare":"1","NetworkSharing":"1","SuperHandoff":"1","SuperKeyMouse":"1","SuperNotification":"1","SuperTerminal":"1","VirtualDeviceService":"1"}

then clean install with the official 3IN1 package (restore OfficeCenter), and launch.
```

Verify: ~5 `Hihonornote.exe` processes alive after 30 s, window title *HONOR WorkStation*. If they die within 20 s → recheck the JSON (BOM!).

## Disclaimer

- Not official. HONOR locks this suite to its own hardware, so the registry part is an **OEM-lock bypass for personal use** — do at your own risk, no warranty, and HONOR support won't help after this.
- Fixed app data lives only in your profile/registry; no app files are modified.
