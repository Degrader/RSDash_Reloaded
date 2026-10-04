# PID Reference

Every value RSdash reads from the ESP32, and where on the car each one most likely comes from. This is the table to start with; the other pages hold the detail.

- The **Key** is the name in the JSON that `GET /pids` returns (see [ESP32 API](ESP32-API.md)).
- The **vehicle-side source** is a CAN frame on the HS-CAN bus ([CAN Frames](CAN-Frames.md)) or a diagnostic DID asked of a module ([Diagnostic DIDs](Diagnostic-DIDs.md)), taken from [openRS_](https://github.com/klexical/openRS_) and FORScan.

**Read the confidence column.** The Nutron firmware's source isn't in this repo, so nothing here is checked against what it reads. The mapping from key to car signal is inferred from the key's meaning and unit.

| Confidence | Meaning |
|---|---|
| **Documented** | A source describes a signal with the meaning and unit the app uses. It doesn't prove the firmware reads it from there. |
| **Candidate** | More than one signal could supply it. Which one the firmware reads isn't known. |
| **Unknown** | No source found, or the sources contradict the app. |

## Engine page

| Key | Reading | Page and limits | Vehicle-side source | Confidence | Notes |
|---|---|---|---|---|---|
| `boost` | Boost, bar | Boost gauge, 0-35 psi; red over 2.2 bar (32 psi) | CAN `0x0F8` byte 5, or PCM DID `0x033E` (`TCBP`) | Candidate | openRS_ lists `0x0F8` boost as absolute kPa and its catalogue notes it didn't work on one car. Whether the firmware subtracts barometric pressure (CAN `0x090` byte 2) isn't known. |
| `gear` | Gear: 0 neutral, 1-6, 7 reverse | Gear display; "-" when the firmware doesn't send it | CAN `0x230` bits 0-3 (RS_HS.dbc) | Unknown | openRS_ found `0x230` isn't broadcast on its car and removed its gear display, so the firmware gets gear some other way. |
| `coolant` | Coolant temperature, °C | Temp gauge, 0-130; red under 60 or over 110 | CAN `0x2F0` bytes 4-5; PCM DID `0xF405` | Documented | |
| `engine` | **Oil** temperature, °C | Oil gauge, 0-150; red under 65 or over 110. Also feeds the Ready To Race logo | CAN `0x0F8` byte 1 | Documented | Named `engine` but used as oil. The sources disagree on which byte of `0x0F8` holds oil, see [CAN Frames](CAN-Frames.md#where-the-sources-disagree). |
| `iat` | Intake air temperature, °C | Temp gauge, -20-80; red over 60 | CAN `0x2F0` bytes 6-7; PCM DID `0xF40F` | Documented | |
| `ptu` | PTU temperature, °C | Temp gauge, 0-130; red under 50 or over 110. Also Ready To Race | CAN `0x0F8` byte 7; AWD DID `0x1E3F` (PTU oil temperature) | Candidate | |
| `rdu` | RDU oil temperature, °C | Temp gauge, 0-130; red under 20 or over 110. Also Ready To Race | AWD DID `0x1E8A` (`R_DIFF_OIL_TMP`) | Documented | `R_DIFF_OIL_TMP` in FORScan's list; openRS_ polls it with `A-40`. |
| `latG` | Lateral G, g | G-force plot and readout; red past 1 g | CAN `0x180` bytes 2-3 | Documented | Which way it points hasn't been checked on the car (`flipLateral` on `GForceGauge`). |
| `longG` | Longitudinal G, g | G-force plot and readout | CAN `0x160` bytes 6-7 | Documented | Same sign caveat (`flipLongitudinal`). |
| `vertG` | Vertical G, g | Readout | CAN `0x180` bytes 0-1 | Documented | |
| `yaw` | Yaw rate, °/s | Yaw bar, ±90 | CAN `0x180` bytes 4-5 | Documented | |
| `steering` | Steering angle, °, positive to the right | Steering bar, ±450 | CAN `0x010` bytes 6-7, sign in byte 4 bit 7 | Documented | |
| `brake` | Brake pressure, % of the sensor's range | Brake bar, 0-100 | CAN `0x252` bytes 1-2 | Documented | |
| `battery` | Battery voltage, V | Battery readout; "--" until read; red under 12 or over 15 | PCM DID `0x0304` (`VPWR`); or the adapter's own supply measurement | Candidate | openRS_ found no CAN frame carrying battery voltage (`0x3C0` doesn't broadcast). The app's own comment says "volts at the OBD port", and openRS_'s WiCAN-based firmware keeps its own `battery_mv`, so the ESP32 may be measuring its supply rather than asking the car. |

## AWD page

`ptu`, `rdu` and `engine` are the same keys as above.

| Key | Reading | Page and limits | Vehicle-side source | Confidence | Notes |
|---|---|---|---|---|---|
| `rdutl` / `rdutr` | RDU left / right clutch temperature, °C | Clutch gauges, 0-120; red over 105 | AWD DIDs `0x1ECF` / `0x1ED0`, or `0x1E8B` / `0x1E8C` | Candidate | openRS_ has two sets: `0x1ECF`/`0x1ED0` in its catalogue (`(signed(A)*256+B)/4`), and `0x1E8B`/`0x1E8C` marked "candidate" in its poller (`A-40`). |
| `rdutql` / `rdutqr` | RDU left / right clutch torque, Nm | Torque bars, split, total | AWD DID `0xEE05` (coupling torque; left bytes A:B, right C:D), `0xEE04` (requested torque), or CAN `0x2C0` | Candidate | The Split and Total bars are worked out in the app from these two. |
| `flw` / `frw` | Tyre pressure, front left / right, bar | Tyre rings, 0-4 bar; red under 35 psi or over 50 psi | BCM DIDs `0x2813` (LF) / `0x2814` (RF) | Documented | |
| `rlw` / `rrw` | Tyre pressure, rear left / right, bar | Same | BCM DIDs `0x2816` (LR) / `0x2815` (RR) | Documented | **The DID order is not the key order**: `0x2815` is rear *right* and `0x2816` rear *left*. |
| `wheelFL` `wheelFR` `wheelRL` `wheelRR` | Wheel speed, km/h | Under each tyre. Slip = (rear average − front average), red over 8 km/h | CAN `0x190` | Documented | |
| `speed` | Vehicle speed, km/h | Under the car | CAN `0x130` bytes 6-7 | Documented | |

## Controls page

| Key | Reading | Used for | Vehicle-side source | Confidence | Notes |
|---|---|---|---|---|---|
| `mode` | Drive mode: 0 Normal, 1 Sport, 2 Track, 3 Drift | The live Drive Mode tile; "Not available" if the key is missing | CAN `0x1B0` byte 6 upper nibble, with `0x420` to tell Sport from Track | Documented | **The numbering is the firmware's.** The CAN nibble is 0 Normal, 1 Sport/Track, 2 Drift, and openRS_'s own firmware numbers the modes 0 Normal, 1 Sport, 2 Drift, 3 Track. Don't mix them up. |
| `esc` | ESP: 0 On, 1 Sport, 2 Off | The live ESP tile | CAN `0x1C0` bits 10-11 | Documented | The CAN values are 0 On, 1 Off, 2 Sport, 3 Launch, so a firmware reading `0x1C0` has to swap Off and Sport. |

## Sent but not read

| Key | Reading | Notes |
|---|---|---|
| `lambda` | Lambda | The RSapp 2.8.1 firmware sends it; the newer firmware always sends 0, so the app dropped the lambda gauge. In openRS_ lambda is PCM DID `0xF434` (`EQ_RAT11`). The **OBD Not Alone** setting makes the ESP32 stop requesting lambda from the engine computer so another OBD device can. |

The settings the app also reads and writes (`enableLC`, `esp`, `disableStartStop`, `driveMode`, `enableDriftMode`, `driftInAllModes`, `cobbFriendly`) are firmware settings, not car signals. They're on the [ESP32 API](ESP32-API.md) page.

## What the car carries that RSdash doesn't show yet

None of these is in `/pids` today. All are on the HS-CAN bus unless noted; the decodes are on [CAN Frames](CAN-Frames.md).

- Engine speed (`0x090`), throttle and accelerator pedal (`0x076`, `0x080`), clutch pedal (`0x138`), ignition status (`0x0C8`), fuel level (`0x380`), engine status and odometer (`0x360`).
- Launch control engaged (`0x225`, `0x420`), and the drive mode, ESP and start-stop button presses (`0x305`, `0x260`).
- Over diagnostics: oil life, knock counters, charge air temperature, fuel pressures, battery state of charge and temperature, cabin temperature, tyre temperature. See [Diagnostic DIDs](Diagnostic-DIDs.md).
- **Lights.** No source confirms them on the HS-CAN bus the ESP32 listens on, but FORScan lists the BCM's lamp PIDs: [Lights and Body Status](Lights-and-Body-Status.md).
