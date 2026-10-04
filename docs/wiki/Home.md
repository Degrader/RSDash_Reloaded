# RSdash Reloaded wiki

RSdash is an app on the Ford Sync 3 screen of the Focus RS Mk3 that shows live gauges from an ESP32 CAN-bus dongle. This wiki is the reference for **what the car can tell us**: the readings the app uses today, where they come from on the car, and the many more that haven't been mapped yet.

The app itself, how to install it and what it looks like are in the [README](https://github.com/Degrader/RSDash_Reloaded#readme).

## Start here

| If you want to know | Go to |
|---|---|
| Every reading the app uses, and where on the car each one comes from | [PID Reference](PID-Reference.md) |
| What the ESP32 serves and what the app sends it | [ESP32 API](ESP32-API.md) |
| Frames the car broadcasts, with how to decode them | [CAN Frames](CAN-Frames.md) |
| Values a module gives when asked (tyre pressures, clutch temps, battery) | [Diagnostic DIDs](Diagnostic-DIDs.md) |
| Everything FORScan can read on this car, by module | [FORScan PIDs](FORScan-PIDs.md) |
| Whether the headlights and other lamps can be shown | [Lights and Body Status](Lights-and-Body-Status.md) |
| How to find a new PID, or check one | [Finding and Confirming PIDs](Finding-and-Confirming-PIDs.md) |
| Where all this came from, and how far to trust it | [Sources and Credits](Sources-and-Credits.md) |

## At a glance

- The app reads **29 keys** from the ESP32's `/pids` (listed on [PID Reference](PID-Reference.md)), plus seven stored settings and two live controls.
- The car has two buses. The ESP32 sits on **HS-CAN** (500 kbps, OBD pins 6 and 14). Some body and cluster signals, such as the lamps in the DigiCluster map, are listed on **MS-CAN** (125 kbps, pins 3 and 11), which the ESP32 doesn't see unless the gateway passes them across.
- FORScan lists **1,148 PIDs across 20 modules**, but the diagnostic address (DID) is known for only 33. Most of them are names without a way to read them yet.
- Most of the information comes from [openRS_](https://github.com/klexical/openRS_), an open-source Android dashboard for the same car and a similar adapter, and FORScan. It's compiled from their documentation. Nothing here was tested on a car for this wiki, and the ESP32 firmware's source isn't available, so each page says how sure it is.

## Words used on these pages

| Word | Meaning |
|---|---|
| **PID** | A named reading, such as coolant temperature. Used loosely for any signal |
| **DID** | The number you ask a module for to get a reading (a data identifier, like `0x2813`) |
| **Broadcast frame** | A CAN message the car sends on its own, identified by its CAN ID (like `0x190`) |
| **HS-CAN / MS-CAN** | The car's fast (500 kbps) and medium (125 kbps) buses |
| **PCM, BCM, AWD, IPC** | The engine computer, body module, all-wheel-drive module (PTU and rear drive unit) and instrument cluster |
| **Documented / candidate / captured** | How sure a source is. [PID Reference](PID-Reference.md) and [Diagnostic DIDs](Diagnostic-DIDs.md) explain each |
