# RSdash Reloaded

This is a modified build of **RSdash**, originally developed by **Au{R}oN - Fmods.net** ([www.fmods.net](https://www.fmods.net)), with ESP32 canbus firmware by **Toki - Nutron Pro Moto** ([www.promoto.nutron.pl](https://www.promoto.nutron.pl)).

RSdash is a free application specifically developed for the Ford Focus RS MK3.5. To use the app "as is," an ESP32 canbus microcontroller with the custom Nutron firmware is REQUIRED — get the firmware and installation guide from the `ESP32 Firmware` folder. Sync 3 has to be connected to the CANbus ESP32 microcontroller's WiFi hotspot.

All credit for the original design, the gauge layout, and the ESP32 firmware goes to the original authors above. This fork keeps their app intact and focuses on tightening up performance on the Sync 3 head unit, plus a few layout and settings changes.

## What's changed in this fork

Starting from v2.3, this build makes the app talk to the ESP32 less often and redraw the gauges only when something actually changes, instead of on fixed timers regardless of activity:

- **Network polling** (`SyncMyMod/app/PrimaryView.qml`, `SyncMyMod/app/Components/Controller.js`)
  - The OBD Alone / Not Alone check (originally the COBB presence check) no longer rides along on the 250ms live-data poll. It now runs on its own 5-second timer, roughly halving the request rate to the ESP32.
  - Both the live-data fetch and the OBD mode check now skip firing a new request if the previous one for that endpoint hasn't finished yet, so a slow response can't cause requests to pile up on the ESP32's single-threaded HTTP server. A request that hasn't finished after 3 seconds is abandoned, so one that never gets a reply (e.g. the ESP32 rebooting mid-response) can't block polling for good.
  - Responses are now checked for a successful HTTP status and safely parsed (try/catch around `JSON.parse`), so a dropped connection or bad reply is logged and skipped instead of throwing inside the poll timer.

- **Gauge rendering** (all `Components/*Gauge.qml` files)
  - Every gauge previously repainted its Canvas on a free-running 100ms timer regardless of whether its value had changed. Gauges now repaint only when their value actually changes.
  - A gauge that's currently hidden (e.g. the TPMS vs. RDU extra-info area, or the invisible "dummy" gauges used to drive drive-mode state) no longer does any redraw work while hidden, and repaints once immediately when it becomes visible again.

- **Assets**
  - Fixed the Ready-to-Race popup referencing a missing `res/rtr2.png`; it now points at the `res/rtr.png` file that's actually shipped.

Starting from v2.5, the NOT ALONE function has moved to the settings page and the main view layout has changed:

- **OBD setting** (`SyncMyMod/app/SettingsView.qml`, `SyncMyMod/app/Nutron.qml`)
  - The original app's NOT ALONE function, for when a COBB Accessport, scan tool or other OBD device is plugged in, is now an **OBD** toggle on the settings page, below Extra View, with the states **Alone** and **Not Alone**. It is no longer toggled by tapping the lambda gauge.
  - The setting is stored on the ESP32 (as `cobbFriendly`), not in `NutronConfig.ini`, so it persists across restarts and stays in sync with the RSapp phone app. The toggle dims while the change is sent and only flips once the ESP32 accepts it.

- **Main view** (`SyncMyMod/app/PrimaryView.qml`, `SyncMyMod/app/Components/SplitPlasmaGauge.qml`)
  - Oil temp is now top-center; lambda is bottom-center.
  - In Not Alone mode the ESP32 stops requesting lambda, the only value it asks the engine computer (PCM) for, so the lambda slot shows both RDU clutch temps side by side in a new split gauge instead. These come from the AWD module and keep updating.

## Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

### [0.1] - 2024-04-25
- Initial Private Release

### [0.4] - 2024-04-26
- Added ESP and Drift Mode Controller
- Improved POST execution time
- Added PSI / BAR and C / F selector

### [1.0] - 2024-08-25
- First Public Release
- Refresh timer set to 1000
- Settings json has been set to be read only at startup(from now on you cannot see SDM changes if they requested through the car IPC)
- Fixed a Syncronization issue between values and GUI

### [2.0] - 2025-03-09
- Heavy code refactory
- Added ECU + / - to select pcm tune (latest ESP32 firmware required)
- Added Left and Right RDU Temp and Torque
- Added the ability to suppress canbus diagnostic in case of multiple obd devices plugged in (latest ESP32 firmware required)
- Added settings page to select default extra view and unit measures

### [2.3] - 2025-10-03
- Temporary removed ECU + / - UI
- Changed the way to switch between TPMS and RDU Views
- Minor UI Adjustments
- Added Ready To Race Popup (it appear when RDU, PTU and OIL (Engine) temps reach the treshold value
- Removed settings button from main page
- Removed close button from secondary page

### [2.3JC] - Reloaded fork
- Decoupled COBB presence polling from the 250ms live-data timer onto its own 5s timer
- Added in-flight request guards to prevent overlapping polls to the ESP32
- Added HTTP status checks and safe JSON parsing around all ESP32 requests
- Switched all gauge Canvas repaints from a fixed 100ms timer to repaint-on-change, skipping hidden gauges
- Fixed the Ready-to-Race popup's missing `res/rtr2.png` reference

### [2.4JC] - 2026-09-26
- Added a 3s timeout to the in-flight request guards so a request that never completes can't stop polling
- Tapping the lambda gauge to enable COBB now shows an orange "COBB APv3 / CONNECTING" state until the ESP32 confirms it; taps are ignored while connecting, and a COBB check runs as soon as the change is accepted instead of waiting for the 5s timer
- Fixed torque gauges drawing the indicator dot
- Installer now keeps the user's existing `NutronConfig.ini` on update (set `OVERWRITE_CONFIG="true"` in `autoinstall.sh` to force a replace)

### [2.5JC] - 2026-09-26
- Moved NOT ALONE from the lambda gauge tap to a new "OBD" setting (Alone / Not Alone) on the settings page, stored on the ESP32 and synced with the RSapp phone app
- In Not Alone mode the lambda slot now shows both RDU clutch temps in a new split gauge, replacing the "COBB APv3" connecting/connected label
- Swapped the Oil and lambda gauges: Oil is now top-center, lambda / RDU clutch temps bottom-center
- Installer replaces `NutronConfig.ini` for this release (`OVERWRITE_CONFIG="true"`), resetting saved units and the extra view to their defaults
