# DreamWeaver watchOS Prototype

Companion app that collects heart-rate metrics overnight and relays snapshots back to the iPhone prototype.

## Files

- `DreamWeaverWatchApp.swift` – App entry point and environment wiring.
- `Views/WatchContentView.swift` – Minimal bedside UI with start/stop controls, vitals, and elapsed timer.
- `Managers/WorkoutManager.swift` – HealthKit workout session, HR/HRV streaming, and periodic pushes to the phone.
- `Managers/WatchConnectivityManager.swift` – Lightweight message bridge back to the iPhone side.

## Adding the Target

1. Open (or create) an Xcode workspace that contains the iPhone sources under `Ihpone/`.
2. `File > New > Target… > watchOS > Watch App`. Name it **DreamWeaver Watch App**.
3. Once generated, remove the template files and drag the contents of `Iwatch/` into the new target group.
4. Enable **HealthKit** and **Background Modes → Workout processing** under Signing & Capabilities.
5. Ensure the Watch scheme is visible (`Product > Scheme > Manage Schemes…`).

## Testing

1. Pair an Apple Watch simulator with your chosen iPhone simulator (`Window > Devices and Simulators`).
2. Run the watch scheme on e.g. *Apple Watch Series 11 (46 mm)*.
3. Tap **Start** on the watch to begin a mock workout. Heart rate and HRV update as HealthKit samples arrive.
4. The manager pushes snapshots every five minutes via WatchConnectivity (see console logs for `sendSnapshot`).
5. Tap **Stop** to terminate the workout session and release timers.

For hardware testing, a physical Watch + iPhone pair on the same Wi-Fi network is recommended. Sign the targets with the same Apple ID and grant HealthKit permissions on first launch.
