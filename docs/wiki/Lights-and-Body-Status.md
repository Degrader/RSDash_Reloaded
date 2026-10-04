# Lights and Body Status

Can RSdash show that the headlights are on, or that it's dark and they've come on by themselves?

**Short answer: the car knows, and there are leads, but nobody has confirmed a signal the ESP32 can read yet.**

- FORScan lists the BCM's lamp PIDs, including the left and right low beams, high beam, position lights, stop lamps, reverse lamp, fog lamps and licence plate lamp. So the state exists in the car and can be read over diagnostics, but the catalogue gives **no DID** for any of them.
- openRS_ carries lamp bits from the DigiCluster project's **MS-CAN** map (low beam, high beam, fog light, turn signals), all unverified. The ESP32 listens on **HS-CAN**, so they'd only reach it if the gateway bridges them.
- No decoded HS-CAN frame in these sources is a headlight status. The nearest thing is a gauge brightness value in `0x0C8`, which may follow the lights. That's an idea to test, not a finding.
- RSdash can't show any of it until the ESP32 firmware reports it in `/pids`. See [ESP32 API](ESP32-API.md).

## What FORScan lists

All are FORScan PID names from [openRS_'s catalogue](FORScan-PIDs.md). None has a known DID, so none can be requested yet. See [Finding and Confirming PIDs](Finding-and-Confirming-PIDs.md).

### BCM (`0x726`)

| PID | Description |
|---|---|
| `LOW_BEAM_LT` | Left headlamp low beam |
| `LOW_BEAM_RT` | Right headlamp low beam |
| `HIGH BEAMS` | High beam |
| `POS_LAMP_LT` | Left position lights duty cycle |
| `POS_LAMP_RT` | Right position lights duty cycle |
| `STOP_LMP_LT` | Left stop lamp duty cycle |
| `STOP_LMP_RT` | Right stop lamp duty cycle |
| `STOP_LMP_CHM` | Central high mounted stop lamp |
| `BRAKE_LMP_SW` | Brake lamp switch |
| `RVRS_LMPS` | Reverse lamp |
| `FOG_LAMPS` | Front fog lamps request |
| `LI_PLATE_LMP` | Licence plate light |
| `LT_SW_INVLD` | Exterior light switch, invalid position |
| `TURN_SW_STK`, `TURN_SW_ICOM`, `TRN_SIG_ICOM`, `TRN_BM_ICOM`, `HI_LOW_ICOM` | Turn stalk and beam switch faults (stuck, illegal combinations) |

The position and stop lamps are listed as duty cycles, which reads like the BCM's drive level, but the catalogue doesn't say.

### Instrument cluster (`0x720`)

The cluster shows the indicators, so it has its own copy of the state.

| PID | Description |
|---|---|
| `HIGH_BEAM` | High beam indicator |
| `LAMPS_ON` | "Lights on" warning |
| `F_FOG_IND` / `R_FOG_IND` | Front / rear fog lamp indicator |
| `LH_TURN_L` / `RH_TURN_L` | Left / right turn signal lamp status |
| `AHBC_CP` | Auto high beam customer preference (a setting, not a state) |
| `ILLUMINATE`, `LCD_ILLUMINAT` | Illumination and LCD illumination level, % |

### Dimming and sensors

| Module | PID | Description |
|---|---|---|
| DDM, PDM (doors) | `DIMM` | Illumination dimming level, % |
| ICM | `ILLUMINATE` | Illumination, % |
| DDM | `P_LAMP`, `SMT_LAMP` | Puddle lamp, side mirror turn signal lamp |
| HVAC (`0x733`) | `SOLAR_SSR_L`, `SOLAR_SSR_R` | Solar radiation sensor, left and right, W |

There is **no PID named for an ambient light or twilight sensor**. If the car has one for automatic headlamps, FORScan's list doesn't name it. The sun-load sensor in the climate module measures sunlight, not whether the headlights are on, but it's the only light-level reading in the list.

## What's been seen on the bus

### On MS-CAN, unverified (DigiCluster map)

| ID | Signal | Where |
|---|---|---|
| `0x080` | Low beam on | B1 bit 7 |
| `0x1A8` | High beam indicator | B1 bit 0 |
| `0x1B0` | Fog light on | B2 bit 4 |
| `0x03A` | Left / right turn signal | B1 bit 2 / bit 3 |

The same IDs on HS-CAN carry unrelated data (`0x080` is the pedals, `0x1B0` the drive mode), so these must never be applied to an HS-CAN capture. The full MS-CAN list is on [CAN Frames](CAN-Frames.md#ms-can-signals-digicluster-map). I haven't checked which car the DigiCluster map was captured on, and every row is flagged `verified: false` in openRS_'s catalogue.

### On HS-CAN

No lamp signal is decoded. One candidate worth logging:

- `0x0C8` byte 0, the low 5 bits (`B0 & 0x1F`), is "gauge brightness". Cars usually dim the panel when the lights come on, so this may change with them. **Untested.** It might only follow the dimmer, which would make it useless for "the headlights came on by themselves".

## Ways it could reach RSdash

| Route | What it needs | Catch |
|---|---|---|
| Ask the BCM over HS-CAN | The DID for a lamp PID (via FORScan, or a DID prober), and firmware that polls it and reports it | The ESP32 firmware is closed (Nutron's). BCM diagnostics are on HS-CAN, so the bus is right. |
| Read a broadcast frame | The frame's ID and bit, from a CAN log | Only if it is on HS-CAN or bridged across. The MS-CAN entries above may not be. |
| Use `0x0C8` brightness as a stand-in | A log showing it changes with the lights | May follow the dimmer only. |

Whichever route works, the app side is small: a new key in `/pids`, a line in the mock ESP32 (`dev/mock_esp32.py`), and an indicator on a page. The hard part is the firmware.

## How to find out

1. Connect a CAN logger (a USB-CAN adapter with SavvyCAN, or the ESP32 if its firmware can log) to the OBD port, and log HS-CAN for each state with the engine off and ignition on: lights off, parking lights, low beam, high beam, fog lights. Hold each state for 10 seconds.
2. Compare the logs. A byte or bit that changes with the lights and nothing else is the candidate. Check `0x0C8` first.
3. For the automatic case, set the switch to Auto and cover the sensor, or park somewhere dark, and see whether the same bit appears.
4. If HS-CAN shows nothing, use FORScan's data logger on the BCM's `LOW_BEAM_LT`, `LOW_BEAM_RT` and `HIGH BEAMS` while you cycle the lights, with a CAN logger running at the same time. FORScan's requests and the BCM's replies appear on the bus, and the DID (or the dynamic definition, if FORScan sets one up) is in the request frame.
5. Send what you find, with the log, so it can be added to [PID Reference](PID-Reference.md).

Details of step 4 are in [Finding and Confirming PIDs](Finding-and-Confirming-PIDs.md).
