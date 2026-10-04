# Sources and Credits

Where the information in this wiki comes from, who did the work, and how far to trust it.

## How far to trust it

This wiki was compiled from documentation, the app's code and the projects below, on 3 October 2026. **None of it was tested on a car for this wiki**, and nothing was checked against the Nutron ESP32 firmware, whose source isn't in this repo. Each page says whether a decode is documented, captured against another tool, or only a candidate; where the sources contradict each other the page says so rather than choosing. If you check something on a car, [write it up](Finding-and-Confirming-PIDs.md) and fix the page.

## openRS_

[openRS_](https://github.com/klexical/openRS_) by klexical and contributors is an Android dashboard for the Focus RS Mk3, for a MeatPi (WiCAN) adapter. It decodes the whole CAN bus and polls modules over diagnostics, and its documentation and catalogues are the main source here. It is MIT licensed.

Used, from the `main` branch on 3 October 2026:

| File | Used for |
|---|---|
| `android/docs/pid-reference.md` | HS-CAN frames, Mode 22 DIDs, module addresses |
| `README.md` | The live CAN list, the polled DID list by module, what doesn't broadcast |
| `android/app/src/main/assets/pids/forscan_modules.json` | The FORScan PID list, by module ([FORScan PIDs](FORScan-PIDs.md)) |
| `android/app/src/main/assets/pids/combined_catalog.json` | The captured PCM DIDs, the AWD and BCM DIDs, the MS-CAN signals |
| `android/app/src/main/java/com/openrs/dash/can/ObdConstants.kt` | Module request and response IDs, which DIDs it polls |
| `android/app/src/main/java/com/openrs/dash/can/CanDecoder.kt` | CAN IDs and the notes on them |
| `firmware/components/focusrs/focusrs.h` | The button frames (`0x305`, `0x260`) and how the drive mode is changed |
| `CONTRIBUTING.md`, `DidProberSection.kt` | What it asks for, and how the DID prober works |

openRS_'s catalogues cite further sources that aren't in this repo and which I haven't read:

- **RS_HS.dbc**, a CAN database for the RS, for most of the HS-CAN frame names (`PCMmsg07`, `ABSmsg02`, ...).
- **DigiCluster**, a project whose HS-CAN and MS-CAN maps (`can0_hs.json`, `can1_ms.json`) it checked against, and the source of the MS-CAN signals.
- Community research from owners, such as [openRS_ discussion #102](https://github.com/klexical/openRS_/discussions/102) (odometer and engine status), [issue #119](https://github.com/klexical/openRS_/issues/119) (TPMS), the focusrs.org RDU tuning thread (clutch current and pressure), and the owners' CAN map spreadsheet.

### openRS_ licence

The tables in this wiki reproduce data from openRS_, so its licence is included as it requires:

> MIT License
>
> Copyright (c) 2026 openRS Contributors
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## FORScan

[FORScan](https://forscan.org/) is the diagnostic program whose PID list for the Focus RS Mk3 openRS_ exported and bundled (`android/scripts/gen_forscan_catalog.py` builds the catalogue from a FORScan export). The PID names, descriptions and units on the FORScan pages are FORScan's. The catalogue gives a DID for only 33 of the 1,148, so the page for each module is a list of names to find DIDs for, not a map of the car.

## This repo

- The `/pids`, `/settings` and `/control` keys, limits and pages come from the app's QML in `SyncMyMod/app/`, the README and the mock ESP32 in `dev/mock_esp32.py`.
- [RSdash](https://github.com/Degrader/RSDash_Reloaded) is a modified build of the original **RSdash** by **Au{R}oN** ([Fmods.net](https://www.fmods.net)), with ESP32 canbus firmware by **Toki** ([Nutron Pro Moto](https://www.promoto.nutron.pl)). The firmware's own source isn't in this repo, which is why the mapping from `/pids` key to car signal is inferred.

## Keeping it current

- The four FORScan pages are generated. If openRS_'s catalogue changes, run `python dev/make_wiki_forscan.py` to rebuild them.
- The other pages are written by hand from the files above. When openRS_ confirms or corrects a decode, update the page and its [PID Reference](PID-Reference.md) row.
