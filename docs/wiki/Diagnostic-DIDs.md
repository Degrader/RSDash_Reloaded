# Diagnostic DIDs

Values the car doesn't broadcast, but a module will give you if you ask. You send a UDS "read data by identifier" request (Mode 22) to a module and it answers with the value. This is how tyre pressures, battery state, clutch temperatures and most of the engine computer's internals are read, and it's what FORScan does.

A request is `22 <DID high> <DID low>` sent to the module's request ID, for example `22 28 13` to `0x726` for the left front tyre pressure. The reply comes from the module's response ID as `62 <DID high> <DID low> <data...>`. An 8-byte CAN frame is `03 62 DD DD` and then the data, so:

- `A`, `B`, `C`, `D` are the first four data bytes after the DID. openRS_ also writes them `B4`, `B5`, ... for their position in the frame.
- Replies longer than one frame are ISO-TP multi-frame: the asker has to send a flow control frame (`30 00 00`) after the first frame.
- `signed(A)` means the first byte is read as a signed value.
- Some DIDs only answer in the extended diagnostic session (`10 03`).

Sources: [openRS_](https://github.com/klexical/openRS_) (`pid-reference.md`, `ObdConstants.kt`, its PID catalogues) and FORScan's PID list. The FORScan names in brackets are on the [FORScan pages](FORScan-PIDs.md); the catalogue ties only 33 of them to a DID itself, so the rest are matched here by name and meaning. How openRS_ marks a DID: **polled** (it asks for it), **captured** (it has a recorded value that was checked), **candidate** (a guess waiting for a DID prober to confirm), **reference** (documented but not used).

## Module addresses

| Module | Request | Response | Source |
|---|---|---|---|
| PCM (engine) and OBD-II | `0x7E0` | `0x7E8` | FORScan; openRS_ |
| BCM (body) | `0x726` | `0x72E` | FORScan; openRS_ |
| AWD (PTU and RDU) | `0x703` | `0x70B` | FORScan; openRS_ |
| IPC (instrument cluster) | `0x720` | `0x728` | FORScan; openRS_ marks it a candidate, no DIDs yet |
| HVAC | `0x733` | `0x73B` | FORScan; openRS_ marks it a candidate, no DIDs yet |
| PSCM (power steering) | `0x730` | `0x738` | FORScan; openRS_ |
| ABS | `0x760` | `0x768` | openRS_ firmware |
| FENG (the engine noise generator) | `0x727` | `0x72F` | openRS_ (extended session) |
| RSPROT | `0x731` | `0x739` | openRS_ probes only; what it is isn't documented |
| GFM | `0x7D2` | not listed | openRS_ scans it for fault codes |

openRS_ polls the PCM and BCM every 30 seconds and the AWD module every 60 seconds. RSdash's own **OBD Not Alone** setting only stops the ESP32 requesting lambda from the engine computer so another OBD device can; the sources don't say how two tools asking the same module at once behave.

## PCM (`0x7E0`)

| DID | Reading (FORScan PID) | Formula | Unit | Status |
|---|---|---|---|---|
| `0x0304` | Module voltage (`VPWR`) | `(A*256+B)/2048` | V | polled; captured (14.90 V) |
| `0x0318` | VCT intake angle (`VCT_INTK_DSD`) | `signed(A*256+B)/16` | ° | polled; captured |
| `0x0319` | VCT exhaust angle (`VCT_EXH_DSD`) | `signed(A*256+B)/16` | ° | polled; captured |
| `0x033E` | Throttle inlet pressure, actual (`TCBP`) | `(A*256+B)/903.81` or `raw/128` | see below | polled; captured |
| `0x0466` | Throttle inlet pressure, desired (`TCBP_DSD`) | same | see below | polled; captured |
| `0x03CA` | Intake air temperature 2 | `A-40` | °C | reference. Likely the charge air after the intercooler |
| `0x03E8` | Octane adjust ratio (`OCTADJ_R_LRND`) | `signed(A*256+B)/16384` | ratio | polled; captured (-1.00) |
| `0x03EC`-`0x03EF` | Knock correction, cylinders 1-4 (`KNK_CNTR_CYL1`-`4`) | `signed(A*256+B)/-512` | ° | polled |
| `0x0461` | Charge air temperature (`CAC_T`) | `signed(A*256+B)/64` | °C | polled |
| `0x0462` | Wastegate (`TURBO_WGATE`) | `A*100/128` or `raw/327.68` | % | polled; captured |
| `0x054B` | Oil life remaining (`OIL_REMAINING`) | `A` | % | polled; captured (35 %) |
| `0x091A` | Throttle, desired (`ETC_DSD`) | `(A*256+B)*(100/8192)` or `raw/512` | see below | polled; captured |
| `0x093C` | Throttle, actual (`ETC_ACT`) | same | see below | polled; captured |
| `0x116B` | Spark advance | not in the sources | | polled |
| `0xF405` | Coolant temperature | `A-40` | °C | reference |
| `0xF406` / `0xF407` | Short / long term fuel trim | `A*100/128-100` | % | polled |
| `0xF40F` | Intake air temperature | `A-40` | °C | reference |
| `0xF422` | High pressure fuel rail (`FRP`) | `(A*256+B)*1.45038` | psi | polled |
| `0xF42F` | Fuel level (`FLI`) | `A*100/255` | % | polled |
| `0xF434` | Lambda, actual (`EQ_RAT11`) | `(A*256+B)*0.0004486` | :1 | polled |
| `0xF43C` | Catalyst temperature (`CATEMP11`) | `(A*256+B)/10-40` | °C | polled |
| `0xF444` | Lambda, desired (`EQRAT11_CMD`) | `A*0.1144` | :1 | polled |

### PCM DIDs captured and checked

openRS_'s catalogue has these 25 with a recorded value. The notes compare them against "AP", presumably a COBB Accessport. Raw means the unsigned count in the reply.

| DID | Name | Formula | Unit | Captured |
|---|---|---|---|---|
| `0x0301` | map_sensor_voltage | `raw / 1024` | V | 0.35 V to 3.88 V, vacuum through 35 psi boost |
| `0x0304` | battery_voltage | `((A*256)+B)/2048` | V | 0x7733 = 30515 counts = 14.90 V |
| `0x0307` | lpfp_duty_cycle | `raw / 163.84` | % | 61.0-62.7 %, AP showed 61.0-62.8 % |
| `0x0318` | vcti_angle_actual | `raw / 16` | ° | -0.2 to 0.4 |
| `0x0319` | vcte_angle_actual | `raw / 16` | ° | 1.1 to 1.9 |
| `0x032B` | accel_pedal_position | `raw / 2` | % | idle 0 %, blip peak 32 % |
| `0x033C` | tip_sensor_voltage | `raw / 1024 * 5` | V | 1.56 V, static |
| `0x033E` | tip_actual_abs | `raw / 128` | kPa | about 98.9 kPa |
| `0x0353` | baro_pressure | `((A*256)+B)*0.25` | kPa | 0x018D = 397 counts = 99.25 kPa |
| `0x035A` | baro_pressure_sensor_voltage | `((A*256)+B)/204.6` | V | 0x0322 = 802 counts = 3.92 V |
| `0x0393` | ac_pressure | `raw * 2.0` | kPa | 0x015F = 351 counts = 702 kPa |
| `0x03BA` | aat_sensor_voltage | `((A*256)+B)/204.6` | V | 0x0146 = 326 counts = 1.59 V |
| `0x03DC` | fuel_rail_pressure_desired | `raw * 10.0` | kPa | raw 175 = 1750 kPa |
| `0x03E8` | oar | `signed(raw) / 16384` | ratio | -1.00 constant |
| `0x041F` | lpfp_pressure_desired | `raw * 0.0117` | kPa | about 648 kPa |
| `0x0462` | wgdc_actual | `raw / 327.68` | % | idle 0 %, blip peak 4.50 % |
| `0x0466` | tip_desired_abs | `raw / 128` | kPa | 98.52 kPa |
| `0x0548` | lowside_fuel_pressure_actual | `raw * 0.5` | kPa | 567-727 kPa |
| `0x054B` | oil_life_left | `raw` | % | 35 % |
| `0x054D` | lpfp_sensor_voltage | `raw * 0.001` | V | 2.36 V to 3.09 V at idle |
| `0x0914` | accel_pedal_position_sens1_voltage | `((A*256)+B)/1024` | V | 0.78 V (0 %) to 4.12 V (100 %) |
| `0x091A` | etc_angle_desired | `raw / 512` | ° | 1.70-1.71, AP range 1.64-1.80 |
| `0x093C` | etc_angle_actual | `raw / 512` | ° | 1.71, matched AP |
| `0x1279` | iat_sensor_voltage | `raw / 204.6` | V | 1.877-1.882 V, AP 1.88 V |
| `0x9800` | ac_pressure_sensor_voltage | `((A*256)+B)/1024` | V | |

## BCM (`0x726`)

| DID | Reading (FORScan PID) | Formula | Unit | Status |
|---|---|---|---|---|
| `0x2813` | Tyre pressure, left front (`TPM_PRES_LF`) | `(((256*A)+B)/3 + 22/3) * 0.145` | psi | polled |
| `0x2814` | Tyre pressure, right front (`TPM_PRES_RF`) | same | psi | polled |
| `0x2815` | Tyre pressure, right rear (`TPM_PRES_RRO`) | same | psi | polled |
| `0x2816` | Tyre pressure, left rear (`TPM_PRES_LRO`) | same | psi | polled |
| `0x280B` | Last received TPMS sensor | see below | | polled |
| `0x280F` / `0x2810` / `0x2811` / `0x2812` | Sensor ID, LF / RF / RR / LR (`TPM_S_ID_*`) | 4-byte ID | | polled once on connect |
| `0x4027` | Battery days in service (`BATTERY_AGE`) | `(A*256)+B` | days | reference |
| `0x4028` | Battery state of charge (`BAT_ST_CHRG`) | `A` | % | polled |
| `0x4029` | Battery temperature (`BAT_TEMP`) | `A-40` | °C | polled |
| `0x4090` | Battery current (`BAT_CURRENT`) | `((A*256+B)/16)-511.7` | A | polled |
| `0x411D` | Battery charging voltage desired (`BAT_V_DSD`) | not in the sources | V | polled |
| `0xDD01` | Odometer (`TOTAL_DIST`) | `A*65536 + B*256 + C` | km | polled once; needs the extended session |
| `0xDD04` | Inside car temperature (`IN-CAR_TEMP`) | `A*10/9-45` | °C | polled |

- **Tyre pressure.** The part in brackets is kPa, which is the unit FORScan lists for these PIDs; `0.145` turns it into psi. openRS_ uses this because it matched known pressures on a Mk3 RS. MeatPi's profile uses `([A:B]/10)/2.036` psi, which openRS_ keeps only as a legacy reference. **The order is not left-right, front-rear**: `0x2815` is right *rear* and `0x2816` is left *rear*.
- **`0x280B`** returns `62 28 0B [ID0 ID1 ID2 ID3] [pressure hi, lo] [temp] [status] [checksum]` in 12 bytes, needing flow control. Pressure is `(A*256+B)/20` psi, temperature is `raw - 40` °C, and the sensor ID says which tyre it belongs to (match it against `0x280F`-`0x2812`). A status under 6 is cached data from an earlier reading and is discarded; 6 or more is live. That is how openRS_ gets tyre *temperature*, one tyre at a time, whichever the BCM heard last.
- **Not supported:** per-tyre temperature at `0x2823`-`0x2826` is rejected by this BCM (`7F 22 31`).

## AWD module (`0x703`)

Covers both the PTU and the rear drive unit (RDU). "Left" and "right" are the RDU's two clutches.

| DID | Reading | Formula | Unit | Status |
|---|---|---|---|---|
| `0x1E3F` | PTU oil temperature | `(signed(A)*256+B)/4` | °C | catalogue |
| `0x1E8A` | RDU oil temperature (`R_DIFF_OIL_TMP`) | `A-40` | °C | polled |
| `0x1ECF` / `0x1ED0` | Left / right clutch temperature | `(signed(A)*256+B)/4` | °C | catalogue |
| `0x1E8B` / `0x1E8C` | Left / right clutch temperature | `A-40` | °C | candidate |
| `0x1E80` | Transmission (sump) oil temperature | | °C | candidate |
| `0x1E90` / `0x1E91` | Left / right requested torque | | | candidate |
| `0x1E92` | Demanded pressure | | | candidate |
| `0x1E93` | Pump motor current | | | candidate |
| `0x1E9E` / `0x1E9F` | Left / right clutch actuator current | `(signed(A)*256+B)/128` | A | polled |
| `0x1ED1` / `0x1ED2` | Left / right clutch pressure | `(signed(A)*256+B)*2` | mbar | polled |
| `0x3B67` | Demand pressure | `(A*256+B)/100` | bar | catalogue |
| `0xD00F` | BLDC motor current | `(signed(A)*256+B)/100` | A | catalogue |
| `0xEE04` | Requested torque: left `A:B`, right `C:D` | `(A*256)+B`, `(C*256)+D` | Nm | catalogue |
| `0xEE05` | Coupling torque: left `A:B`, right `C:D` | same | Nm | catalogue |
| `0xEE0B` | RDU status | | | queried in the extended session; meaning not documented |

FORScan also lists `AWD_ECU_TMP` (module temperature) and `AWD_SWTCH_ST` (mode select switch) with no DID; see the [AWD section](FORScan-Other-Modules.md#awd---all-wheel-drive-module).

## Other modules

| Module | DID | Reading | Notes |
|---|---|---|---|
| ABS | `0x2B06`-`0x2B09` | Wheel speeds 1-4 | catalogue; formula `A` km/h |
| ABS | `0x2B0C` | Lateral acceleration | `(signed(A)*256+B)*0.002` g; catalogue |
| ABS | `0x2B11` | Longitudinal acceleration | same; catalogue |
| PSCM | `0xFD07` | Pull drift compensation | `A == 1` means enabled; polled in the extended session |
| FENG | `0xEE03` | Engine noise generator status | queried in the extended session |
| RSPROT | `0xDE00`, `0xDE01`, `0xDE02`, `0xEE01`, `0xFD01` | unknown | openRS_ probes these to find out |
| IPC | none | Warning lamps | openRS_: "DIDs unconfirmed, use the DID prober" |
| HVAC | none | Blower, temperatures, blend doors | same |

## Where the sources disagree

- **Throttle inlet pressure (`0x033E`, `0x0466`).** `pid-reference.md` has `(A*256+B)/903.81` labelled kPa, and its Mode 1 table has the same divisor labelled psi. The captured entries use `raw / 128` kPa. On the same count, `/128` gives 98.9 kPa and `/903.81` gives 14.01, which is psi (98.9 kPa is 14.3 psi). So `/903.81` is a psi formula despite the kPa label, and it's about 2 % off the captured one. Check against a known pressure before trusting either.
- **Wastegate (`0x0462`).** One byte, `A*100/128`, in `pid-reference.md`, the FORScan catalogue and the Mode 22 list; two bytes, `raw/327.68`, in the captured entry. `pid-reference.md` calls it "desired", the captured entry "actual".
- **Throttle angle (`0x091A`, `0x093C`).** `(A*256+B)*(100/8192)` in `pid-reference.md` (labelled %) and the Mode 22 list (labelled °), against `raw/512` degrees in the captured entries ("1.71° matched AP"). The two scalings differ by 6.25 times.
- **VCT angles (`0x0318`, `0x0319`).** FORScan names them "desired"; the captured entries call them "actual". Same formula.
- **RDU clutch temperatures.** Two sets of DIDs, `0x1ECF`/`0x1ED0` and `0x1E8B`/`0x1E8C`, with different formulas. The second set is marked "candidate" in openRS_'s poller.
- **Fuel rail pressure (`0xF422`).** FORScan's unit is kPa; openRS_ multiplies by 1.45038 and stores psi.
