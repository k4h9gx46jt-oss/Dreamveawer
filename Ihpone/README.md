# DreamWeaver iPhone Prototype

This SwiftUI prototype mirrors the DreamWeaver specification inside `Doc/`. It ships with mock data, simulated AI dream generation, and placeholder WatchConnectivity hooks so you can preview the full user journey entirely in the simulator.

## Structure

```
Ihpone/
├── DreamWeaverApp.swift
├── Models/
├── Services/
└── Views/
```

- **Models** define the SwiftData-ready entities (`SleepData`, `BiosignalDataPoint`, `DreamMood`).
- **Services** simulate AI interpretation and Watch/HealthKit integrations.
- **Views** reproduce the dashboard, tracker, detail sheet, and visualization layers described in the docs.

## Running in Xcode

1. Open Xcode → `File > Open...` → select the `Ihpone` folder.
2. Choose *App* template when prompted, replace generated files with the provided sources.
3. Target **iOS 17** or newer, and enable the *HealthKit* and *WatchConnectivity* capabilities if you plan to connect to the watch prototype.
4. Build & run on an iPhone 16 simulator (or physical iPhone running iOS 17+).

## Testing Workflow

1. Tap **Start Dream Mode** on the hero card.
2. Let the mock tracker run for ~10 seconds (live vitals are simulated but update every 5 seconds).
3. Tap **Stop Tracking** and wait for the “Interpreting your dream…” progress view to complete.
4. A new dream card appears in the dashboard. Tap it to open the detail screen, review the AI narrative, tags, intensity bars, and heart-rate chart.
5. Tap the visualization hero to watch the particle animation inspired by the dominant dream mood.

## Next Steps

- Replace `AIDreamService` with real OpenAI/Anthropic calls (see `Doc/AI_DREAM_GUIDE.md`).
- Connect `PhoneWatchConnectivityManager` to the actual shared WatchConnectivity manager once the watch target lives inside the same Xcode project.
- Swap the mock `SleepData.mock()` data with persisted SwiftData once schema migrations are set.
