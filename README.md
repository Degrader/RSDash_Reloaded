# RSdash Reloaded

This is a modified build of **RSdash**, originally developed by **Au{R}oN - Fmods.net** ([www.fmods.net](https://www.fmods.net)), with ESP32 canbus firmware by **Toki - Nutron Pro Moto** ([www.promoto.nutron.pl](https://www.promoto.nutron.pl)).

RSdash is a free application specifically developed for the Ford Focus RS MK3.5. To use the app "as is," an ESP32 canbus microcontroller with the custom Nutron firmware is REQUIRED — get the firmware and installation guide from the `ESP32 Firmware` folder. Sync 3 has to be connected to the CANbus ESP32 microcontroller's WiFi hotspot.

All credit for the original design, the gauge layout, and the ESP32 firmware goes to the original authors above. This fork keeps their app and workflow intact and focuses on tightening up performance on the Sync 3 head unit.

## What's changed in this fork

Starting from v2.3, this build makes the app talk to the ESP32 less often and redraw the gauges only when something actually changes, instead of on fixed timers regardless of activity:

- **Network polling** (`SyncMyMod/app/PrimaryView.qml`, `SyncMyMod/app/Components/Controller.js`)
  - The COBB Access Port presence check no longer rides along on the 250ms live-data poll. It now runs on its own 5-second timer, roughly halving the request rate to the ESP32.
  - Both the live-data fetch and the COBB check now skip firing a new request if the previous one for that endpoint hasn't finished yet, so a slow response can't cause requests to pile up on the ESP32's single-threaded HTTP server.
  - Responses are now checked for a successful HTTP status and safely parsed (try/catch around `JSON.parse`), so a dropped connection or bad reply is logged and skipped instead of throwing inside the poll timer.

- **Gauge rendering** (all `Components/*Gauge.qml` files)
  - Every gauge previously repainted its Canvas on a free-running 100ms timer regardless of whether its value had changed. Gauges now repaint only when their value (or, for the lambda gauge, its COBB state) actually changes.
  - A gauge that's currently hidden (e.g. the TPMS vs. RDU extra-info area, or the invisible "dummy" gauges used to drive drive-mode state) no longer does any redraw work while hidden, and repaints once immediately when it becomes visible again.

- **Assets**
  - Fixed the Ready-to-Race popup referencing a missing `res/rtr2.png`; it now points at the `res/rtr.png` file that's actually shipped.

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
