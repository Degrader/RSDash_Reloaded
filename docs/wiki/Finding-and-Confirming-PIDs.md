# Finding and Confirming PIDs

Most of the pages in this wiki say "documented", "candidate" or "unmapped". This page is how to turn those into answers, using tools an owner can get. It's written for the open questions here, such as the lights, but works for any signal.

## What you're looking for

| Kind | What it is | You need | Example |
|---|---|---|---|
| **Broadcast frame** | The car sends it on its own, many times a second | The CAN ID, the byte and bit, and the scaling | Wheel speeds, `0x190` |
| **Diagnostic DID** | A module only answers when asked | The module's request ID and the DID | Tyre pressure, `0x2813` from the BCM `0x726` |

FORScan's PID list gives you names for the second kind, but not their DIDs, and for most of the 1,148 PIDs nobody has published the DID. See [FORScan PIDs](FORScan-PIDs.md).

## Tools

- **FORScan** with an adapter it supports. It reads the PIDs by name and can graph and log them. It's the quickest way to know a PID *exists* and *what it should read* in a given situation.
- **A CAN logger**, which listens without sending: a USB-CAN adapter with [SavvyCAN](https://www.savvycan.com/), or a MeatPi WiCAN streaming frames to an app that logs them (openRS_ does this and gets about 2,100 frames a second), on the OBD port. HS-CAN is pins 6 and 14 at 500 kbps. Passive listening doesn't change anything in the car.
- **openRS_'s DID prober.** In the [openRS_](https://github.com/klexical/openRS_) Android app (with a MeatPi adapter), it sends Mode 22 requests to a chosen module across the common Ford DID ranges plus the catalogue's, and reports each as found, rejected (the module refused that DID) or no reply. It's how openRS_ finds new DIDs.

Stay to **reading**. Mode 22 requests and passive logging don't alter anything. Don't send write services (`2E`, `2F`, `31`) or put frames on the bus unless you know exactly what they do.

## Recipes

### Find the DID behind a FORScan PID

1. Start a CAN logger on HS-CAN.
2. In FORScan, connect, open the module (say, the BCM) and start logging the PID you care about, for example `LOW_BEAM_LT`.
3. Change the real thing while it runs: switch the headlights on and off. Watch FORScan's value change, and note the time.
4. In the log, look for requests sent to the module's request ID (BCM `0x726`, PCM `0x7E0`; see [Diagnostic DIDs](Diagnostic-DIDs.md#module-addresses)). A request is `03 22 <DID high> <DID low>`, and the reply from the response ID is `... 62 <DID high> <DID low> <data>`. The data bytes that follow the DID are the value.
5. FORScan may read several PIDs in one request, or set up a dynamic definition first. If so, log it with only that one PID selected to see which DID is yours.
6. Compare the reply with FORScan's value across the changes to work out the formula.

### Find a broadcast frame for a state

1. Log HS-CAN with the thing in one state, say 10 seconds with the lights off.
2. Change it and log again, 10 seconds with the lights on. Change only that, and nothing else (no pedals, no doors).
3. Compare the two logs frame by frame, ID by ID. An ID whose bytes differ between the two and are steady within each is the candidate.
4. Repeat with more states, such as high beam, to see which bit is which. Then repeat the first state to make sure it comes back.

### Check a decode

Compare the decoded value against something you trust at several points: a calibrated reading from FORScan or a COBB Accessport, the car's own gauge, or a known reference (tyre pressure from a gauge, odometer from the dash). The [Diagnostic DIDs](Diagnostic-DIDs.md#where-the-sources-disagree) page shows why: several formulas in openRS_'s own files disagree by a factor, and only a comparison tells you which is right.

## Writing it up

A finding is only useful if someone else can repeat it. For each signal, record:

- the **bus** and ID (broadcast), or the **module**, request ID and DID (diagnostic);
- the **byte and bit**, or the bytes and **formula**, and the unit;
- the **values you saw** in each state, as raw bytes (for example, `<ID> B<n> = 0x00` with the lights off and `0x01` with low beam, using the real ID and byte);
- the **car**: model year, tune and ESP32 firmware if relevant, and what else was connected;
- how you **checked it**, and what it was compared against;
- a log excerpt, if you can.

Add it to [PID Reference](PID-Reference.md) and the page for its kind, marked with how it was checked, in the same wording the other pages use (documented, candidate, captured).

## Passing it on

openRS_'s [CONTRIBUTING notes](https://github.com/klexical/openRS_/blob/main/CONTRIBUTING.md) list "additional BCM/IPC PIDs" and MS-CAN parameters among the things they need help verifying, and say PID dumps from FORScan or an OBDLink MX+ are valuable. The lights are exactly that, so a finding is worth sharing there too.
