# Building and Running the Watch Target

**Scope:** how to build, install and run the watchOS app. For capability
configuration see [WATCH_APP_SETUP.md](WATCH_APP_SETUP.md).

> This document previously referenced a project named `Dream Vewawer` at
> `/Users/SEV0A/Iphone/GJSPO/...`. **That path and project name no longer exist.**
> All paths below are current.

---

## 1. Project location

```
Ihpone/DreamWeaver/DreamWeaver.xcodeproj
```

One project, five targets. Watch sources live in `Iwatch/`, iOS sources in
`Ihpone/`, and `Shared/` is compiled into both platforms.

| Scheme | Runs on |
| --- | --- |
| `DreamWeaver` | iPhone |
| `DreamWeaver WatchKit App` | Apple Watch |

---

## 2. Helper scripts

Run these from the repository root.

| Script | Purpose |
| --- | --- |
| `./run-tests.sh` | Unit tests plus a watchOS compile check |
| `./run-tests.sh --watch` | Only the sleep-staging suite |
| `./run-tests.sh --all` | Unit and UI tests |
| `./start-dreamweaver.sh` | Boot simulators, build and launch |
| `./test-and-start.sh` | Test, then launch if green |
| `./reinstall.sh` | Clean reinstall on the booted simulators |

Override the iOS simulator with `DREAMWEAVER_IOS_SIM_NAME`:

```bash
DREAMWEAVER_IOS_SIM_NAME="iPhone 17" ./run-tests.sh
```

---

## 3. Running from Xcode

1. Open `Ihpone/DreamWeaver/DreamWeaver.xcodeproj`.
2. Select the **DreamWeaver WatchKit App** scheme.
3. Pick a paired Apple Watch simulator or a physical watch.
4. Press ⌘R.

If the watch scheme is missing: **Product → Scheme → Manage Schemes**, tick
`DreamWeaver WatchKit App`.

---

## 4. Simulator pairing

```bash
xcrun simctl list devices available     # find UDIDs
xcrun simctl list pairs                 # check existing pairs
```

Pair through **Xcode → Window → Devices and Simulators → Simulators** if no pair
exists. Both devices must be booted before WatchConnectivity will activate.

---

## 5. Simulator limitations

**Apple Watch simulators do not provide real HealthKit data.** In the simulator you
can verify:

- ✅ UI layout and navigation
- ✅ WatchConnectivity message flow
- ✅ Session lifecycle and state reconciliation
- ✅ REM classifier logic (via unit tests)

You cannot verify:

- ❌ Real heart rate, HRV, SpO₂ or respiratory rate
- ❌ Battery consumption
- ❌ Overnight background survival
- ❌ Extended runtime session behaviour

Anything battery- or sensor-related **must** be tested on physical hardware.

---

## 6. Physical device testing

1. Pair the Apple Watch with the iPhone.
2. Sign both targets with the same team (`28TCC8Y78C` by default).
3. Install the iPhone app first, then the watch app.
4. Trust the developer profile on both devices.
5. Grant HealthKit permission on first launch.

> **Blocker:** the HealthKit entitlement is currently missing from every target,
> so authorization will fail on hardware. Fix
> [APP_STORE_CHECKLIST.md](APP_STORE_CHECKLIST.md) §0.1 first.

---

## 7. Troubleshooting

| Symptom | Fix |
| --- | --- |
| Watch scheme not listed | Product → Scheme → Manage Schemes |
| `CopyAndPreserveArchs` failure from the command line | Build the watch scheme from the Xcode GUI instead |
| Watch shows "not reachable" | Both simulators booted and paired; both devices unlocked |
| No heart rate on device | HealthKit permission granted **and** entitlement present |
| Stale build after source changes | `rm -rf .derivedData` then rebuild |

---

## 8. Current configuration

| Setting | Value |
| --- | --- |
| iOS deployment target | 26.2 |
| watchOS deployment target | 11.0 |
| iPhone bundle ID | `GJDRW.DreamWeaver` |
| Watch app bundle ID | `GJDRW.DreamWeaver.watchkitapp` |
| Watch extension bundle ID | `GJDRW.DreamWeaver.watchkitapp.watchkitextension` |
| Development team | `28TCC8Y78C` |
| Code signing | Automatic |

> The bundle identifiers are not in reverse-DNS form and should be changed before
> the first App Store submission — they cannot be changed afterwards.
