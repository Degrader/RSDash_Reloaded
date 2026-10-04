# ESP32 API

What RSdash says to the ESP32 and what comes back. The ESP32 is the dongle plugged into the OBD port; the Sync 3 joins its Wi-Fi and talks HTTP to `http://192.168.80.1/`. Everything here is what the **app** reads and sends; the firmware's source isn't in this repo, so keys the app doesn't use are only known from the mock and the older RSapp 2.8.1 firmware.

| Endpoint | Used for |
|---|---|
| `GET /pids` | Live readings. Polled every 250 ms on the two gauge pages (the refresh rate), every second on the Controls page |
| `GET /settings` | The ESP32's saved settings. Re-read every 5 s on the Controls page, and when the settings page opens |
| `POST /settings` | Change one setting, e.g. `{"cobbFriendly": 1}` |
| `POST /control` | Change the car's drive mode or ESP **now**, e.g. `{"mode": 2}` or `{"esc": 1}`. Nothing is saved |

## `GET /pids`

Returns one JSON object. The app reads the keys on [PID Reference](PID-Reference.md) and ignores the rest. A key the firmware doesn't send is left alone, so the gauge stays at its start value; that's how the app copes with the older firmware.

Units are what the ESP32 sends: °C, bar, Nm and km/h. The app converts to the units chosen on its settings page.

This is what the mock ESP32 (`dev/mock_esp32.py`) sends by default. It's a made-up car, but it has the shape and units of the real thing:

```json
{
  "ptu": 62, "rdu": 58, "engine": 92, "lambda": 0.98,
  "flw": 3.0, "frw": 3.0, "rlw": 2.95, "rrw": 2.95,
  "rdutl": 71, "rdutr": 74, "rdutql": 120, "rdutqr": 135,
  "mode": 0, "esc": 0,
  "boost": 0.9, "coolant": 91, "iat": 28,
  "speed": 87, "wheelFL": 87, "wheelFR": 87.5, "wheelRL": 86.5, "wheelRR": 87,
  "gear": 3, "latG": 0.35, "longG": 0.2, "vertG": 1.0,
  "battery": 13.8,
  "yaw": 6, "steering": -40, "brake": 20
}
```

### Which firmware sends what

| Firmware | Sends |
|---|---|
| RSapp 2.8.1 (the original, in `ESP32 Firmware RSapp2.8.1.zip`) | Tyre pressures, `ptu`, `rdu`, `engine`, the clutch temps and torque, and `lambda`. No `/control`. |
| The newer Nutron firmware (not in this repo) | Everything in the example above; `lambda` is always 0. Takes `POST /control`. |

With the 2.8.1 firmware the missing readings stay at zero, the gear and battery show "-" and "--", and the live Drive Mode and ESP tiles say "Not available".

## `GET` and `POST /settings`

The Controls page reads and writes these. They're the ESP32's own preferences, stored on it, so they stay in sync with the RSapp phone app. They are not car signals.

| Key | Values | What it does |
|---|---|---|
| `enableLC` | 0 off, 1 on | Launch Control. Works right away |
| `esp` | 0 off, 1 on | **ESP Sport** at startup: the car starts in ESP Sport from the next start |
| `disableStartStop` | 0 off, 1 on | Turns auto start-stop **off** from the next start (so 1 means start-stop is off) |
| `driveMode` | 0 Normal, 1 Sport, 2 Track, 3 Drift, 5 Custom | The drive mode the car starts in. 5 (Custom) leaves the car's mode alone and is no longer offered by the app, but the tile still shows it if it's saved |
| `enableDriftMode` | 0 off, 1 on | Drift Stick (rear wheel lock through the ABS; needs a flashed ABS module) |
| `driftInAllModes` | 0 Drift mode only, 1 all modes | Where Drift Stick works. The app shows `enableDriftMode` and `driftInAllModes` as one choice: Off, Drift Only, All Modes |
| `cobbFriendly` | 0 Alone, 1 Not Alone | Not Alone makes the ESP32 stop requesting lambda from the engine computer, so a COBB Accessport or scan tool can |

The mock also serves `units`, `wifi`, `product`, `protocol` and `version`, which the app never reads.

## `POST /control`

Presses the car's own buttons through the ESP32.

| Body | Effect |
|---|---|
| `{"mode": 0-3}` | Drive mode: 0 Normal, 1 Sport, 2 Track, 3 Drift. Takes about 5 seconds |
| `{"esc": 0-2}` | ESP: 0 On, 1 Sport, 2 Off |

The tiles then say "Changing to ..." until `/pids` reports the new `mode` or `esc`.

| Status | The app takes it to mean |
|---|---|
| 200 | Accepted |
| 503 | The car isn't ready (asleep, or no CAN) |
| 404 | This firmware doesn't have `/control` |
| none | The ESP32 couldn't be reached |

openRS_'s own firmware does something similar, by sending the button frames the car would see (`0x305` for the drive mode button, `0x260` for ESP Off and start-stop), pressing the drive mode button repeatedly to scroll to the mode and then waiting up to 6 seconds for the car's own auto-confirm. That's consistent with the 5 seconds here, but it's openRS_'s method; how the Nutron firmware does it isn't documented. See [CAN Frames](CAN-Frames.md).

## How the app talks to it

- A poll is skipped if the last one for the same endpoint hasn't finished, because the ESP32's HTTP server is single-threaded and overlapping requests only add delay.
- A request unanswered after 3 seconds is abandoned, so an ESP32 that reboots mid-reply can't block polling.
- Replies are checked for a 200 status and parsed in a try/catch; a bad one is logged and skipped.

## Adding a reading

For something new such as light status, the app needs three things once the firmware sends the value:

1. A key in `/pids`, such as `headlights`. The ESP32 firmware has to add it.
2. An entry in the `pidsData` list of the page that shows it (`PrimaryView.qml` or `AwdView.qml`), with the key as its `param`, and whatever draws it.
3. The same key and a value in `DEFAULT_PIDS` in `dev/mock_esp32.py`, so the harness can show it.

Then add the row to [PID Reference](PID-Reference.md).
