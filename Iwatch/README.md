# DreamWeaver — watchOS Target

The sensor side: records biosignals overnight, classifies sleep stages, and streams
samples to the iPhone. See [../README.md](../README.md) for the project overview and
[../Doc/STATUS.md](../Doc/STATUS.md) for verified feature status.

---

## Files

| File | Role |
| --- | --- |
| `DreamWeaverWatchApp.swift` | App entry point |
| `ExtensionDelegate.swift` | Background refresh; drains `RemoteCommandStore` |
| `Managers/WorkoutManager.swift` | `HKWorkoutSession`, sampling, REM classification, extended runtime, session restore |
| `Managers/WatchConnectivityManager.swift` | `WatchSideConnectivityManager` — command handling, snapshot push |
| `Managers/RemoteCommandStore.swift` | Queues commands that arrive while the extension is suspended |
| `Views/WatchContentView.swift` | Start/stop, live vitals, HR chart, timer |
| `Views/DreamWeaverWordmark.swift` | Calligraphic branding |
| `WatchExtension-Info.plist` | Checked-in plist (`GENERATE_INFOPLIST_FILE = NO`) |

`../Shared/REMClassifier.swift` is compiled into this target as well as the iOS one.

---

## Building

The target already exists in `../Ihpone/DreamWeaver/DreamWeaver.xcodeproj`. Select
the **DreamWeaver WatchKit App** scheme and run.

From the repository root:

```bash
./run-tests.sh --watch      # sleep-staging suite
./run-tests.sh              # full unit suite + watchOS compile check
```

Details: [../Doc/WATCH_SETUP.md](../Doc/WATCH_SETUP.md).

---

## Behaviour

- Samples are captured every **1 second** and pushed to the phone every **5 seconds**.
- `REMClassifier` labels each sample: heart rate `< 50` → deep; `50...75` with
  HRV `>= 35` → REM; otherwise light.
- `WKExtendedRuntimeSession` keeps the runtime alive overnight.
- Session state is persisted to `UserDefaults` so a relaunch resumes rather than
  loses the night.
- If a start command arrives while the extension is suspended, it is queued in
  `RemoteCommandStore` and a `WKExtension` background refresh is scheduled to drain
  it. Without this, starting Dream Mode from the iPhone with the watch app closed
  did nothing.

Twelve signals are recorded per sample. Heart rate, HRV, SpO₂, respiratory rate,
environmental audio exposure and movement are real HealthKit reads. ECG confidence,
apnea risk, hypertension risk, sleep score and wrist temperature delta are
heuristics or placeholders — **none of them are clinical measurements.**

---

## Configuration blockers

Both must be fixed before the app functions on real hardware:

- **No HealthKit entitlement.** No `.entitlements` file exists for any target, so
  `requestAuthorization` fails silently on device.
- **No `UIBackgroundModes`.** `workout-processing` must be declared or the system
  terminates overnight sessions.

The usage description strings *are* present in `WatchExtension-Info.plist`, but the
iOS target has none. Details: [../Doc/WATCH_APP_SETUP.md](../Doc/WATCH_APP_SETUP.md).

---

## Testing

**Watch simulators do not provide real HealthKit data.** In the simulator you can
verify UI, message flow and session lifecycle. You cannot verify heart rate,
battery consumption, or overnight background survival.

Overnight battery drain is **unmeasured**. The 1 s / 5 s cadence is aggressive and
adaptive sampling is planned — see
[../Doc/APPLE_WATCH_ROADMAP.md](../Doc/APPLE_WATCH_ROADMAP.md) §3.

For hardware testing, pair a physical Watch and iPhone, sign both targets with the
same team, install the iPhone app first, and grant HealthKit permission on first
launch.

---

## Backlog

Bedside Mode · Smart Wake · REM-timed haptic cues for lucid dream training ·
complications · adaptive sampling · real ECG capture · Health app write-back.

Detail: [../Doc/APPLE_WATCH_ROADMAP.md](../Doc/APPLE_WATCH_ROADMAP.md).
