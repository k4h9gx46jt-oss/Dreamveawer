# DreamWeaver — iOS Target

The iPhone side: receives biosignals from the watch, segments REM windows, and
renders the dream film and score. See [../README.md](../README.md) for the project
overview and [../Doc/STATUS.md](../Doc/STATUS.md) for verified feature status.

---

## Structure

```
Ihpone/
├── Models/
│   ├── SleepData.swift          Finished dream record + REMDreamProfile, REMSegment
│   ├── BiosignalDataPoint.swift One sample, 12 signals
│   ├── DreamMood.swift          Mood enum + colour palettes
│   ├── SleepDataStore.swift     In-memory store + SleepSession
│   └── REMWindow.swift
├── Services/
│   ├── DreamMediaComposer.swift   Media orchestration, score synthesis, DSP
│   ├── DreamFilmRenderer.swift    Visual profiles + AVAssetWriter
│   ├── WatchConnectivityManager.swift
│   ├── AIDreamService.swift       Narrative — STUB
│   ├── HealthKitManager.swift     Authorization only
│   └── ParticleEngine.swift       Legacy visualisation
├── Views/
│   ├── ContentView.swift
│   ├── DreamDashboardView.swift
│   ├── SleepTrackingView.swift
│   ├── DreamDetailView.swift
│   ├── DreamVideoView.swift
│   ├── DreamVisualizationView.swift
│   └── Components/
└── DreamWeaver/                 Xcode project + test targets
```

---

## Building

```bash
open DreamWeaver/DreamWeaver.xcodeproj
```

Or from the repository root: `./run-tests.sh`, `./start-dreamweaver.sh`.

---

## Key facts

- **`SleepData` is a `Codable` struct, not a SwiftData `@Model`.** The only
  SwiftData usage is the unused Xcode template file
  `DreamWeaver/DreamWeaver/Item.swift`, which should be deleted.
- **`SleepDataStore` is in-memory and seeded with two mock dreams.** Nothing is
  persisted. This is the largest gap in the project.
- **`AIDreamService` is a stub.** It ignores the session it is given and returns
  randomised values plus one of six hardcoded narratives. There is no OpenAI or
  Anthropic integration and there never has been.
- **`DreamMediaComposer` and `DreamFilmRenderer` are the real engine** — ~2 500
  lines producing a genuine MP4 and an original score. No third-party dependencies,
  no Metal, no SceneKit, no diffusion model.
- **The iOS target has no HealthKit entitlement and no usage description strings.**
  HealthKit calls will crash on a real device.

---

## Testing the flow in the simulator

1. Tap **Start Dream Mode**.
2. Let the tracker run — without a paired watch the vitals are simulated.
3. Tap **Stop Tracking** and wait for interpretation to finish.
4. A dream card appears. Open it for charts, narrative and theme tags.
5. Play the dream film. Note that generation needs a non-nil `remProfile`,
   otherwise `ComposerError.missingREMProfile` is thrown.

Dreams disappear when the app restarts — this is expected until persistence exists.

---

## Next steps

Ordered by priority; detail in
[../Doc/APP_STORE_CHECKLIST.md](../Doc/APP_STORE_CHECKLIST.md) and
[../Doc/PRODUCT_ROADMAP.md](../Doc/PRODUCT_ROADMAP.md).

1. Add a persistence layer and remove the seeded mocks
2. Add the HealthKit entitlement and iOS usage description strings
3. Add `PrivacyInfo.xcprivacy`
4. Replace `AIDreamService` with an on-device engine
5. Expose the rendered MP4 via `ShareLink`
6. Delete `DreamWeaver/DreamWeaver/Item.swift`
7. Add settings, onboarding, empty states and notifications
8. Migrate hardcoded strings to a String Catalog before any translation work
