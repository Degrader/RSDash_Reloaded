# Dev harness

Runs RSdash on a PC against a fake ESP32, so changes can be checked before they go on the car. Nothing in this folder is installed on the Sync 3 (the installer only copies `SyncMyMod/app`).

Needs Python 3 and PyQt5:

```
python -m pip install PyQt5
```

## Running the checks

```
python dev/harness.py              # everything, about 40 s
python dev/harness.py obd          # only scenarios with "obd" in the name
python dev/harness.py --list       # what each scenario covers
```

Each run does three things:

- **Static checks for the Sync 3's older Qt.** The app targets QtQuick 2.6, whose JavaScript engine is ES5-only, so this fails on things like `let`, `const` and arrow functions. It also fails on any QML import newer than the ones the original app uses.
- **Scenarios** that click through the real UI (taps land on the app's own `MouseArea`s) and check the results: what's visible, what was sent to the ESP32, and what was saved to the ini.
- **QML warnings and errors.** Any warning fails the run. This catches broken references, binding loops and bad assignments that the Sync 3 would silently log.

Screenshots go to `dev/out/` (not committed). The exit code is 0 only if everything passed.

## README screenshots

```
python dev/harness.py --readme-shots
```

This re-renders the screenshots shown in the main README into `docs/screenshots/`, which are committed. Run it after a UI change, then commit the updated images.

The harness uses a real window parked off-screen, so it won't take focus. The app gets a temp copy of `NutronConfig.ini`, so your repo copy is never changed.

## Clicking around yourself

```
python dev/harness.py --interactive              # 800x480 window, OBD Alone
python dev/harness.py --interactive --not-alone  # start in OBD Not Alone
python dev/harness.py --interactive --animate    # live values drift over time
```

Anything the app sends to the ESP32 is printed in the terminal.

## Files

- `harness.py` - the runner and the scenarios. Add a new scenario by writing a function decorated with `@scenario`; `h.click("someId")`, `h.eval("js expression")`, `h.check(...)` and `h.shot("name")` cover most needs.
- `mock_esp32.py` - the fake ESP32. It serves `/pids` and `/settings` with the same JSON keys as the RSapp 2.8.1 firmware, and can be made slow, offline, or reject changes. It also runs on its own: `python dev/mock_esp32.py`.
- `Host.qml` - stands in for the Sync 3 Custom Apps Loader, which provides `backMouseArea` and `back()` to the app.

## What it can't tell you

- **Qt version.** This is Qt 5.15, not the Sync 3's older Qt. The static checks cover the common problems, but not every difference.
- **Fonts.** The Sync 3 uses different fonts, so text fit in screenshots is approximate.
- **Performance.** A PC is much faster than the head unit.
- **The real ESP32 firmware.** For that, connect the PC to the dongle's "RS" Wi-Fi and look at `http://192.168.80.1/pids` and `/settings`.
