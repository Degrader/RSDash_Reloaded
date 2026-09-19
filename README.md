# RSdash App for Ford Sync 3 developed by Au{R}oN - Fmods.net - www.fmods.net.
# ESP32 Firmware, developed by Toki - Nutron Pro Moto -  www.promoto.nutron.pl.

RSdash is a free application specifically developed for Ford Focus RS MK3.5 vehicle. 
To use the app 'as it is', without any modification, an ESP32 canbus microcontroller with a special crafted custom firmware is REQUIRED. You can get the firmware and the installation guide from the ESP32 Firmware folder.
Sync 3 has to be connected to the CANbus ESP32 Microcontroller WiFi HotSpot.


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