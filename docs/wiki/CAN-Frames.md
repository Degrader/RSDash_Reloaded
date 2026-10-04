# CAN Frames

The frames the Focus RS Mk3 broadcasts on its own, which an adapter on the OBD port can read without asking anyone. This is where most of the live gauges (speed, G, temperatures, drive mode) can come from.

| Bus | OBD port pins | Speed | What the ESP32 sees |
|---|---|---|---|
| HS-CAN | 6 and 14 | 500 kbps | Everything below in the first table. The primary bus. |
| MS-CAN | 3 and 11 | 125 kbps | Only what the gateway (GWM) bridges across, such as ambient temperature on `0x1A4`. openRS_ says it needs a second adapter for the rest. |

Bytes are numbered from 0 (`B0` is the first data byte), and `<<` and `&` are the usual shift and mask. "Motorola" means big-endian bit numbering. The sources are [openRS_](https://github.com/klexical/openRS_) (`pid-reference.md`, `CanDecoder.kt`, its firmware headers), which in turn cite `RS_HS.dbc`, the DigiCluster project's HS-CAN and MS-CAN maps, and the owners' community research. Where a decode has been checked on a car, openRS_ says so; this page doesn't claim more than it does.

## HS-CAN frames

| ID | Signal | Decode | Source |
|---|---|---|---|
| `0x010` | Steering wheel angle | `((B6&0x7F)<<8 \| B7) × 0.04395` °; sign from B4 bit 7 (1 = right, 0 = left) | RS_HS.dbc `SASMmsg01` |
| `0x030` | Cruise control buttons | B5: ON bit 0, OFF bit 1, CANCEL bit 4, RES bit 5, SET+ bit 7; B4 bit 0: SET- | DigiCluster HS-CAN |
| `0x070` | Torque at the transmission; RS suspension button | Motorola `bits(37,11) - 500` Nm; suspension button B7 bit 7 | RS_HS.dbc; openRS_ `CanDecoder` |
| `0x076` | Throttle | `B0 × 0.392` % | RS_HS.dbc. May not broadcast on all tunes |
| `0x080` | Accelerator pedal, brake pedal, reverse | pedal `((B0&0x03)<<8 \| B1) / 10` %; brake B0 bit 2; reverse B0 bit 5 | RS_HS.dbc; DigiCluster |
| `0x090` | Engine speed, barometric pressure | RPM `((B4&0x0F)<<8 \| B5) × 2`; baro `B2 × 0.5` kPa | RS_HS.dbc |
| `0x0C8` | Gauge brightness, handbrake, ignition status | brightness `B0&0x1F`; handbrake `B3&0x40`; ignition `B2&0x1F` (0 key out, 7 running, 9 cranking) | DigiCluster HS-CAN; RS_HS.dbc |
| `0x0F8` | Oil temperature, boost, PTU temperature | oil `B1 - 50` °C; boost `B5` absolute kPa; PTU `B7 - 60` °C | RS_HS.dbc `PCMmsg07` |
| `0x130` | Vehicle speed | `(B6<<8 \| B7) × 0.01` km/h | DigiCluster HS-CAN |
| `0x138` | Clutch pedal | 10-bit Motorola × 0.1 % | RS_HS.dbc `PCMmsg10` |
| `0x160` | Longitudinal G | `((B6&0x03)<<8 \| B7) × 0.00390625 - 2.0` g | DigiCluster HS-CAN |
| `0x180` | Lateral G, yaw rate, vertical G | lateral `((B2&0x03)<<8 \| B3) × 0.00390625 - 2.0` g; yaw `((B4&0x0F)<<8 \| B5) × 0.03663 - 75` °/s; vertical `((B0&0x03)<<8 \| B1) × 0.00390625 - 2.0` g | RS_HS.dbc `ABSmsg02` |
| `0x190` | The four wheel speeds | FL, FR, RL, RR, each 15-bit Motorola `× 0.011343006` km/h | RS_HS.dbc `ABSmsg03` |
| `0x1A4` | Ambient temperature | `B4` signed `× 0.25` °C | MS-CAN, bridged by the gateway; community research |
| `0x1B0` | Drive mode (coarse) | `(B6>>4) & 0x0F`: 0 Normal, 1 Sport or Track, 2 Drift. Use only frames with `B4 == 0` | RS_HS.dbc `AWDmsg01` |
| `0x1C0` | ESP mode | bits 10-11 (byte 1 bits 5-4): 0 On, 1 Off, 2 Sport, 3 Launch | RS_HS.dbc; checked on the bus |
| `0x1E0` | Wheel rotation counts | four 8-bit rolling counts (FL, FR, RL, RR) plus the average front wheel speed | RS_HS.dbc `ABSmsg06` |
| `0x225` | Launch control engaged | B5 bit 3 | openRS_ `CanDecoder` |
| `0x252` | Brake pressure | `((B1&0x0F)<<8 \| B2) / 40.95` % (12-bit, 0-4095 counts) | RS_HS.dbc `ABSmsg10` |
| `0x260` | ESP Off and auto start-stop buttons | ESP Off: B5 bit 4 (`0x10`); start-stop: B0 bit 0 (`0x01`). Set while the button is held | openRS_ firmware; community map |
| `0x2C0` | AWD left and right rear torque | two 12-bit words (bits 0-11 and 12-23), Nm | DigiCluster HS-CAN |
| `0x2F0` | Coolant and intake air temperature | coolant `((B4&0x03)<<8 \| B5) - 60` °C; IAT `((B6&0x03)<<8 \| B7) × 0.25 - 127` °C | RS_HS.dbc `PCMmsg16` |
| `0x305` | Drive mode button | B4 bit 2 (`0x04`) = pressed; B4 bit 4 (`0x10`) = the mode selector is on the cluster | openRS_ firmware |
| `0x340` | Ambient temperature | `B7` signed `× 0.25` °C. **Not** TPMS | RS_HS.dbc `PCMmsg17` |
| `0x360` | Odometer, engine status | odometer `(B3<<16 \| B4<<8 \| B5)` km; engine status `B0`: 0 idle, 2 off, 183 running, 186 kill, 191 recent start, 196 warm-up | RS_HS.dbc; community ([openRS_#102](https://github.com/klexical/openRS_/discussions/102)) |
| `0x380` | Fuel level | `((B2&0x03)<<8 \| B3) × 0.4` % | RS_HS.dbc `PCMmsg30` |
| `0x40A` | VIN (multiplexed), odometer | three pages of 6 bytes make the 17-character VIN | community |
| `0x420` | Drive mode (detail), launch control | B6: `0x10` Normal, `0x11` Sport or Track, `0x12` Drift; B7 bit 0: 0 Sport, 1 Track; launch control `(B6>>2) & 1`. About every 600 ms | RS_HS.dbc; found by experiment |

**Not broadcast on openRS_'s car:** `0x230` (gear position, `bits(0,4)` in the DBC) and `0x3C0` (battery voltage). Battery voltage is asked of the engine computer instead; see [Diagnostic DIDs](Diagnostic-DIDs.md).

## Where the sources disagree

Cross-check these on your own car before relying on them.

- **Oil temperature in `0x0F8`.** `pid-reference.md` and the README put oil at B1 (`- 50`) and PTU at B7 (`- 60`). openRS_'s catalogue has an `oil_temp` entry at B7 (`- 60`, "observed 0x8E = 82 °C"), which is the PTU decode in the other table. Treat oil = B1 and PTU = B7 as the documented answer.
- **Track mode.** openRS_'s Android decoder reads `0x1B0` as Sport and Track sharing nibble 1, and uses `0x420` B7 bit 0 to tell them apart. The firmware header says `0x1B0` nibble 3 is Track ("confirmed from live CAN log"). Both are in the same project; they can't both be right.
- **Accelerator pedal in `0x080`.** The README and catalogue decode it from bits 0-9 (`/ 10`). `pid-reference.md` lists "bytes 2-3 / 2.55" for throttle and accelerator pedal on the same ID.
- **Boost in `0x0F8`.** openRS_'s catalogue notes the B5 boost "does NOT work in my car".
- **The same ID means different things on the two buses.** `0x070`, `0x080`, `0x1B0`, `0x230`, `0x2C0` and `0x340` all appear on both HS-CAN and MS-CAN with unrelated contents. Never apply an MS-CAN decode to an HS-CAN capture, or the other way round.

## MS-CAN signals (DigiCluster map)

openRS_'s catalogue carries these from the DigiCluster project's MS-CAN map, every one flagged `verified: false`. They are on the bus the ESP32 does **not** listen to, so they only reach it if the gateway bridges them. Single bits are numbered from 0 at the least significant bit of the byte, worked out from the catalogue's start bit; multi-bit fields are worded as the catalogue words them, because its start bits mix two numbering conventions.

| ID | Signal | Decode |
|---|---|---|
| `0x020` | Cruise control status | B0: `0x03` off, `0x0F` on and inactive, `0x07` on and active, `0x23` paused, `0x2B` transitional |
| `0x03A` | Turn signals, reverse switch, cruise set speed | left turn B1 bit 2; right turn B1 bit 3; reverse switch B4 bit 5 (`0x80` not reverse, `0xA0` reverse); set speed `B5 × 0.5` km/h |
| `0x060` | Seat belt warning | B0 bit 5 (`0xDC` off, `0xEC` on) |
| `0x070` | Traction control | B4 bit 5 = TCS fault ("confirmed via CAN injection test"); B0-B1: `0x0098` default, `0x10D8` TCS off, `0x00B8` ESC off (needs a 5 s hold) |
| `0x080` | **Low beam**, power mode, doors | low beam B1 bit 7; power mode B2 bits 0-3 (0 sleep, 2 awake, 3 just off, 6 ignition, 7 running); doors B3 low nibble (0 = open: driver, passenger, left rear, right rear); hood and boot B3 high nibble |
| `0x1A4` | Ambient temperature | `B4` signed `× 0.25` °C |
| `0x1A8` | **High beam** indicator | B1 bit 0 |
| `0x1B0` | **Fog light**, RS drive mode button | fog light B2 bit 4; drive mode button B1 (`0x5A` released, `0x5E` pressed), RS only |
| `0x230` | Clock | B5 hour (0-23), B6 minute |
| `0x240` | Parking brake | B3 bit 7 (`0x40` off, `0xC0` on) |
| `0x250` | MIL and oil pressure warnings | MIL: 3-bit value starting at B0 bit 5 (1 or 4 off, 5 on, 6 flash); oil pressure: B1 bits 3-6 (1 or 10 off, 11 on) |
| `0x2C0` | Odometer | B5-B7, km |
| `0x340` | Tyre pressures | B2 LF, B3 RF, B4 LR, B5 RR, PSI |
| `0x345` | RS drive mode selection | B4-B5, RS only |

The catalogue also has placeholders with no ID yet: ABS fault, brake fault, oil pressure and TPMS. The lights rows are discussed on [Lights and Body Status](Lights-and-Body-Status.md).
