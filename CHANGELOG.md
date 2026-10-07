# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

From 2.7.0 on, versions are MAJOR.MINOR.PATCH, set in `SyncMyMod/app/version.txt` (the "JC" suffix marks this fork):

- **MAJOR** for big or incompatible changes, such as needing new ESP32 firmware
- **MINOR** for new features and changes that stay compatible
- **PATCH** for bug fixes only

## [0.1] - 2024-04-25
- Initial Private Release

## [0.4] - 2024-04-26
- Added ESP and Drift Mode Controller
- Improved POST execution time
- Added PSI / BAR and C / F selector

## [1.0] - 2024-08-25
- First Public Release
- Refresh timer set to 1000
- Settings json has been set to be read only at startup(from now on you cannot see SDM changes if they requested through the car IPC)
- Fixed a Syncronization issue between values and GUI

## [2.0] - 2025-03-09
- Heavy code refactory
- Added ECU + / - to select pcm tune (latest ESP32 firmware required)
- Added Left and Right RDU Temp and Torque
- Added the ability to suppress canbus diagnostic in case of multiple obd devices plugged in (latest ESP32 firmware required)
- Added settings page to select default extra view and unit measures

## [2.3] - 2025-10-03
- Temporary removed ECU + / - UI
- Changed the way to switch between TPMS and RDU Views
- Minor UI Adjustments
- Added Ready To Race Popup (it appear when RDU, PTU and OIL (Engine) temps reach the treshold value
- Removed settings button from main page
- Removed close button from secondary page

## [2.3JC] - Reloaded fork
- Decoupled COBB presence polling from the 250ms live-data timer onto its own 5s timer
- Added in-flight request guards to prevent overlapping polls to the ESP32
- Added HTTP status checks and safe JSON parsing around all ESP32 requests
- Switched all gauge Canvas repaints from a fixed 100ms timer to repaint-on-change, skipping hidden gauges
- Fixed the Ready-to-Race popup's missing `res/rtr2.png` reference

## [2.4JC] - 2026-09-26
- Added a 3s timeout to the in-flight request guards so a request that never completes can't stop polling
- Tapping the lambda gauge to enable COBB now shows an orange "COBB APv3 / CONNECTING" state until the ESP32 confirms it; taps are ignored while connecting, and a COBB check runs as soon as the change is accepted instead of waiting for the 5s timer
- Fixed torque gauges drawing the indicator dot
- Installer now keeps the user's existing `NutronConfig.ini` on update (set `OVERWRITE_CONFIG="true"` in `autoinstall.sh` to force a replace)

## [2.5JC] - 2026-09-26
- Moved NOT ALONE from the lambda gauge tap to a new "OBD" setting (Alone / Not Alone) on the settings page, stored on the ESP32 and synced with the RSapp phone app
- In Not Alone mode the lambda slot now shows both RDU clutch temps in a new split gauge, replacing the "COBB APv3" connecting/connected label
- Swapped the Oil and lambda gauges: Oil is now top-center, lambda / RDU clutch temps bottom-center
- Installer replaces `NutronConfig.ini` for this release (`OVERWRITE_CONFIG="true"`), resetting saved units and the extra view to their defaults

## [2.6JC] - 2026-09-26
- Fixed the settings page not re-reading the OBD mode when opened (an error on the line before it stopped it running)
- Fixed a binding loop warning in the Ready To Race popup trigger (no change in behavior)
- Added the `dev/` test harness (PC only, not installed)
- Installer still replaces `NutronConfig.ini` (`OVERWRITE_CONFIG="true"`), resetting saved units and the extra view to their defaults

## [2.7.0JC] - 2026-09-26
- Switched to MAJOR.MINOR.PATCH version numbers
- Drive mode page: the left group is now DRIFT STICK, with Drift Fury renamed to Drift Stick Enabled and moved to the far left, and the two DRIFT IN buttons replaced by one All Modes / Drift Mode Only toggle that's locked while Drift Stick is disabled
- Drive mode page: added the ESP Sport button under OTHERS, where Drift Stick was (moved from the main view)
- Drive mode page: the ASS button shows the auto start/stop symbol instead of text, drawn in QML so it scales and matches the button colours
- Main view: removed the ESP button (now on the drive mode page); LC moved between the four big gauges and the logo to the top of the right column
- Main view: the split gauge's caption is now "OBD" above "NOT ALONE"
- Main view: tire pressures and RDU torque are shown together, replacing the TPMS / RDU extra view; removed the Extra View setting
- Main view: tapping the RDU Torque row switches it to the RDU clutch temps and back
- Temperature gauges show a blue mark where "cold" ends and a red mark where "hot" starts (their low and high thresholds)
- RDU clutch temps now turn red above 105 °C (was 120 °C, the top of the scale), with a red mark at 105
- Tire pressures now turn red below 35 psi and above 50 psi (was 1.9 / 3.0 bar, about 27.6 / 43.5 psi), with blue and red marks at those limits
- Harness: added drive mode page, RDU row toggle and tire pressure scenarios, and checks for the new main view layout
- Installer still replaces `NutronConfig.ini` (`OVERWRITE_CONFIG="true"`), resetting saved units to their defaults

## [2.8.0JC] - 2026-09-27
- Main view: added a column of buttons down the left edge for LC, ESP Sport, drive mode, auto start/stop and Drift Stick, in that order; LC moved there from between the big gauges, and the big gauges are 210 px (was 220 px)
- Main view: the drive mode button shows the current mode and fans the five modes out in an arc to its right; tapping it again, tapping outside, or 8 seconds without a pick closes the fan without a change
- Main view: added the settings button (top left, beside the close button)
- Main view: removed the logo; the right column now shows the RDU clutch temps above the RDU torque, so all four RDU values are always visible, replacing the tap-to-switch RDU row; labelled like the TPMS rows (Temps, RDU, Torque), with the RDU values slightly smaller so four-digit torque clears the label
- Buttons and drive modes are lit in the gauges' blue (was green)
- Removed the drive mode page; its All Modes / Drift Only toggle is now on the settings page as "Drift Stick", locked while Drift Stick is disabled
- Settings page: the back button returns to the main view
- Removed the `checkDummyGauges()` helper and the flag that triggered it from `fetchData()` / `sendData()` (the drive mode button reads the mode directly)
- Harness: added main view button, drive mode fan, RDU rows and Drift Stick setting scenarios, and layout checks for the button column and the four right-hand rows; removed the drive mode page and RDU row toggle scenarios
- Installer still replaces `NutronConfig.ini` (`OVERWRITE_CONFIG="true"`), resetting saved units to their defaults

## [2.9.0JC] - 2026-09-27
- OBD Not Alone: the gauge in lambda's place shows the RDU torque split (each rear clutch's share of the total, in %) instead of the RDU clutch temps, which are now always in the right column
- Torque split reads 0 / 0 below 10 Nm total rear torque, and never turns red
- Main view: the logo is back, centred between the four big gauges, pulsing as before (50 px tall, as it was at the top of the right column)
- `SplitPlasmaGauge` has a `valueSpread` setting for how far apart its two values sit
- Main view: tapping Drift Stick fans out All Modes / Drift Only / Off, replacing the on/off tap and the settings page's Drift Stick toggle; the button's status shows the current choice
- `DriveModeFan` is now `RadialFan`, a general fan with its options and direction set by the page
- Added a video tour (`docs/tour.gif`, `docs/RSDashTour.mp4`), recorded by `dev/tour.py`
- Harness: Not Alone checks cover the torque split; added scenarios for all torque on one side and low torque, and for the Drift Stick fan (including a rejected change); shared fan layout checks; removed the settings page Drift Stick scenario
- Installer still replaces `NutronConfig.ini` (`OVERWRITE_CONFIG="true"`), resetting saved units to their defaults

## [2.10.0JC] - 2026-09-27
- Gauges: removed the round indicator circle; the coloured bar ends in a flat cut straight across the ring, exactly at the value (the start stays rounded, and no bar is drawn at the bottom of the scale)
- The value bar on all three gauge types is drawn by one shared `drawValueArc()` in `Controller.js`
- Main view: the logo is 80 px tall (was 50), centred in the free space between the big gauges' rings, which is 17 px higher than before
- Main view: the drive mode button reads Drive / <mode> / Mode, with the mode larger (new `topText` line on `ButtonGauge`)
- Fans: the stand-in for the button while a fan is open has a solid centre, so the button's own text no longer shows through behind "Close"
- Harness: added a pixel check that the bar is cut flat across the ring at the value, keeps its rounded start, and draws nothing at the bottom of the scale; the logo checks now measure against each ring as drawn (its arc, thickness and marks) and require 8 px of room at full pulse; video tour and screenshots re-rendered
- Installer still replaces `NutronConfig.ini` (`OVERWRITE_CONFIG="true"`), resetting saved units to their defaults

## [2.11.0JC] - 2026-09-27
- Settings page: added a Controls Help button (bottom left) that opens a page explaining what each main view control does
- Harness: added a controls help scenario and README screenshot; the video tour visits the help page
- Installer still replaces `NutronConfig.ini` (`OVERWRITE_CONFIG="true"`), resetting saved units to their defaults

## [2.12.0JC] - 2026-09-28
- Main view: each left-column button lights its ring in its own colour: LC orange, ESP cyan, Drive Mode blue, Auto Start-Stop green, Drift Stick aqua (off stays grey)
- The fans light the current choice in their button's colour, and the controls help page matches
- `ButtonGauge` repaints when its colour changes
- Main view: every left-column button is an icon filling its centre; only Drive Mode (mode name) and Drift Stick (current choice) have text, on a black tab over the bottom of the ring. The drive mode fan shows each mode's icon, and the controls help page uses the same icons
- Icons are traced SVGs in `docs/icons/`, converted by `dev/make_icons.py` (straight-line paths: M/L/H/V/Z, one or more per icon) into `Components/Icons.js` and drawn by `Components/SvgIcon.qml` on the QtQuick canvas; `ButtonGauge` has new `icon`, `iconSize`, `iconOffset`, `badgeText`, `badgeSize`, `badgeOffset` and `statusSize` settings
- Removed `StartStopIcon.qml` (replaced by the auto start-stop icon)
- Harness: added a pixel check of each button's ring colour, lit and off, and of the Drift Stick fan's lit choice; checks each button's icon and label, that each icon fits inside its ring and is actually drawn, and each drive mode's icon in the fan
- Installer still replaces `NutronConfig.ini` (`OVERWRITE_CONFIG="true"`), resetting saved units to their defaults

## [2.13.0JC] - 2026-09-28
- Drive mode fan: headed "Startup drive mode", saying it applies the next time the car starts (the ESP32's drive mode, ESP Sport and auto start-stop settings are startup preferences, not live controls)
- Changing drive mode, ESP Sport or auto start-stop shows a short note that it applies from the next start, or that the ESP32 couldn't be reached
- The app re-reads the ESP32's settings every 5 seconds instead of only when it opens, so it shows the right settings even if it opened before the Sync 3 joined the ESP32's Wi-Fi
- Controls help: descriptions follow the RSdash manual (automatic Launch Control, startup settings, Drift Stick as ABS rear wheel lock)
- Harness: startup settings scenario (notes, fan heading, failed change, catching up with the ESP32)
- Installer still replaces `NutronConfig.ini` (`OVERWRITE_CONFIG="true"`), resetting saved units to their defaults

## [2.14.0JC] - 2026-09-28
- Settings page: Nutron's logo and an "ESP32 device and firmware by Nutron Pro Moto" credit above the author credit
- The main view's logo image is renamed `res/mountuners.png`; `res/nutron.png` is now Nutron's logo
- Harness: checks the Nutron logo loads and sits clear of the settings
- Installer still replaces `NutronConfig.ini` (`OVERWRITE_CONFIG="true"`), resetting saved units to their defaults

## [2.15.0JC] - 2026-09-28
- New Controls page, opened by tapping the logo on the main view: Launch Control, ESP Sport, Drive Mode, Auto Start-Stop and Drift Stick as tiles in a three-column grid, with room for more
- Drive Mode and Drift Stick open a pop-up of their options instead of fanning out; Launch Control, ESP Sport and Auto Start-Stop switch with a tap, each with a short note saying what it did
- Main view: the button column and fans are gone and the gauges are centred; the settings button moved to the bottom left corner; removed `RadialFan.qml`
- Controls help: explains the logo and each control on the Controls page
- Harness: Controls page, drive mode pop-up, Drift Stick pop-up and settings sync scenarios replace the main view button and fan scenarios; README screenshots of the Controls page and its pop-ups
- Installer still replaces `NutronConfig.ini` (`OVERWRITE_CONFIG="true"`), resetting saved units to their defaults

## [2.16.0JC] - 2026-09-30
- Controls page: split into an untitled top row that changes the car now (Drive Mode, ESP, Launch Control, Drift Stick) and Startup (Drive Mode, ESP Sport, Auto Start-Stop)
- New live Drive Mode and ESP tiles: they show the car's current mode (from `/pids`) and change it now with `POST /control`; they say "Changing to ..." until the car has made the change, and why a change failed. Needs the rebuilt ESP32 firmware
- Tiles are smaller to fit two rows; the startup tiles no longer say "at startup"
- `fetchData` skips values missing from the response; `sendData` passes the HTTP status to its callback
- Controls help: the startup Drive Mode and ESP Sport mention the live tiles
- The startup Drive Mode pop-up no longer offers Custom; a Custom already saved on the ESP32 still shows on the tile
- Harness: the mock ESP32 reports `mode`/`esc` and takes `POST /control`; Controls scenarios cover both groups and the new live controls (changing, failing, not available); screenshots and tour updated
- Installer still replaces `NutronConfig.ini` (`OVERWRITE_CONFIG="true"`), resetting saved units to their defaults

## [2.17.0JC] - 2026-10-01
- The main view is now two pages. The engine page has boost, gear, a G-force plot, coolant, oil, intake, PTU and RDU temps, small brake, steering and yaw bars, and the date and time; the logo opens a new AWD page with the PTU, RDU and clutch temps, each clutch's torque, the torque split, total torque and front/rear slip on the left, and a top-down Focus RS with each tyre's pressure and wheel speed, and the car's speed, on the right
- A Controls button on the far left of both pages (the green `controls_grid_right` icon) opens Controls; the logo switches pages instead. Controls and settings go back to the page you left
- Removed the lambda gauge and the Not Alone torque split gauge (the new firmware always reports lambda as 0); the OBD toggle stays on the settings page but no longer affects the gauge pages
- New Speed unit toggle (km/h, mph) on the settings page; `SpeedUnit` in `NutronConfig.ini`
- New `PageChrome`, `ReadyToRace`, `GForceGauge`, `BarGauge` and `CarTopView` components; `Controller.formatValue()` and `unitLabel()`
- Controls help: new Controls button row, and the logo row is now "Logo - Second page"
- Harness: engine page, gear, speed units, AWD page, tyre limits, hot PTU/RDU, clutch torque lines and page navigation scenarios replace the old main view ones; the mock ESP32 sends all the new values; screenshots and tour updated
- Installer still replaces `NutronConfig.ini` (`OVERWRITE_CONFIG="true"`), resetting saved units to their defaults

## [2.17.1JC] - 2026-10-01
- Engine page: the battery voltage at the OBD port, between the brake, steering and yaw bars and the clock; "--" until the ESP32 has a reading, red under 12 V or over 15 V. The bars are narrower to make room
- Harness: battery checks, and the mock ESP32 sends `battery`; engine page screenshot updated
- `version.txt` still said 2.17.0 when this went out; 2.18.0 corrects it
- Installer still replaces `NutronConfig.ini` (`OVERWRITE_CONFIG="true"`), resetting saved units to their defaults

## [2.18.0JC] - 2026-10-03
- Units now default to imperial: Fahrenheit, PSI, Lb-Ft and mph (it was Celsius, bar, Nm and km/h). They're set in `NutronConfig.ini` and built into the app, so a missing or unreadable ini no longer leaves the temperature, pressure and torque units blank. The settings page still switches each one
- Removed code nothing used: `AlternativeButtonGauge`, `ECUGauge` and `SplitPlasmaGauge`, `Controller.getValueREADABLE()`, the `ignoreUnit` and `valueOffset` settings, and `ButtonGauge`'s status, top text and badge options
- `PlasmaGauge` now draws every ring gauge (`SemiCircularGauge` is gone), with the usual colours, angles and size as defaults, and has `outOfRange`. New `TempGauge` and `TyreGauge` hold the settings the temperature and tyre rings share, which takes about 250 lines out of the two gauge pages
- `CustomToggle` handles its own tap and emits `toggled(value)`, so the settings page's unit toggles are four lines each; the ini is saved from the app's unit settings
- `Controller.PSI_PER_BAR` and `psiToBar()` replace `14.5038` written out in five places, and the unit conversion table is built once
- Fixed a small negative reading showing as "-0" (the AWD page's Slip read "-0 mph" at rest)
- AWD page: the car is now a picture of the Focus RS from above (`res/car_top.png`, made from `docs/car/focus_rs_top.webp` by `dev/make_car.py`, which fills a gap in the picture's roof and takes out its own tyres), in place of a line drawing. The four tyres are still drawn on top, in the picture's style, so each turns red with its pressure. The car is 180 px wide (was 200), about the same height
- Settings: new tire pressure limits, Min and Max, for other tires like drag radials. The AWD page's tire rings, their blue and red marks and the tires on the car go red outside them (35 and 50 psi unless changed). Each tap is 1 psi, or 0.1 bar when the units are bar, and holding repeats; Reset to default puts them back. Saved in `NutronConfig.ini` as `TirePressureMinPsi` and `TirePressureMaxPsi`, and a pair that makes no sense is ignored. The units are now on the left of the page and the limits on the right; new `LimitStepper` component
- The dev harness's `--interactive` window starts in the app's default units (it was metric, from the scenarios' pinning)
- Controls: the top row's pop-ups are headed "Drive Mode" and "ESP" (they said "Drive mode now" and "ESP now")
- Fixed stale comments (the Controls page opens from the left-edge button; the OBD toggle no longer changes the gauge pages)
- README: the running "What's changed in this fork" section is now "What it does", describing the app as it is, with the red limits and what it reads from the ESP32; new "Firmware and install" section, which says what the bundled RSapp 2.8.1 firmware can't feed
- Harness: scenarios still start in the ESP32's own units (`start_app(units="shipped")` uses the app's), new `default_units` and `tire_limits_setting` scenarios, a check for "-0"; the screenshots and the video tour are rendered in the default units
- New screenshots: the engine and AWD pages past their limits, the engine page in metric, Ready To Race, the live drive mode and ESP pop-ups, the Controls page while a drive mode change is under way, and the tire pressure limits with the AWD page they set up
- Installer still replaces `NutronConfig.ini` (`OVERWRITE_CONFIG="true"`), resetting saved units and tire pressure limits to their defaults, which are now imperial
