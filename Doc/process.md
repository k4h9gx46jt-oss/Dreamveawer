# DreamWeaver Code & Documentation Alignment

## 1. High-Level Flow
- **Pre-sleep setup** (Instruction.md): `ContentView` presents the "Start Dream Mode" CTA, routing to `SleepTrackingView` where the user arms a session. This mirrors the doc flow (iPhone stays bedside, Watch collects data).
- **During sleep**: 
  - If a Watch is reachable, `SleepTrackingView` asks `WatchConnectivityManager` to `startSleepSession`. The Watch `WorkoutManager` boots an `HKWorkoutSession`, streams HR/HRV every five minutes, and acknowledges with `sessionStarted` as prescribed in APPLE_WATCH_INTEGRATION.md.
  - When the Watch is unreachable, the iPhone view keeps the timers and simulated vitals so the UI remains responsive (fallback described in doc).
- **Morning / on stop**:
  - `SleepTrackingView.stopTracking` requests a stop on the Watch, instantiates `SleepData`, attaches the session UUID so deferred Watch packets land on the right record, and launches `AIDreamService`.
  - `AIDreamService` executes the provider chosen in AI_DREAM_GUIDE.md (OpenAI, Anthropic, or default local). On success it populates `SleepData` with narrative, themes, symbolism, intensity, consciousness, and visual prompt.
  - Returning to `ContentView`, the new `SleepData` becomes the "Last Dream" card. `DreamDetailView` renders charts and the visualization entry point, matching the "Morning" step in Instruction.md.

## 2. Data Model Mapping
- `SleepData` encapsulates the metrics called out in Instruction.md (duration, HR, HRV, movement, REM %, deep %, ambient noise). It also stores AI augmentations enumerated in AI_DREAM_GUIDE.md and maintains a cascade-linked `biosignalTimeline` for Watch samples.
- `BiosignalDataPoint` (per APPLE_WATCH_INTEGRATION.md) captures timestamped HR/HRV/movement readings, linked back to the session.

## 3. Apple Watch Integration Chain
- **Connectivity layer**: `WatchConnectivityManager`
  - Activates the default `WCSession`, tracks reachability/install state, and exposes bindings consumed by `SyncStatusView` to deliver the UX cues described in SYNC_STATUS.md.
  - Sends `startSleep`/`stopSleep`/`getCurrentMetrics` commands and expects `biosignalData` packets, exactly matching the command schema listed in APPLE_WATCH_INTEGRATION.md.
  - Persists received samples into SwiftData, keyed by session UUID, then refreshes live vitals for the tracking view.
- **Watch execution**: `WorkoutManager`
  - Requests HealthKit permission (HKWorkoutType + HR) per WATCH_SETUP.md.
  - Handles `startSleep` by generating a session UUID, starting an `.other` indoor workout, and booting timers for elapsed time and 5-minute dispatch cadence in line with the doc.
  - Delivers biosignal metrics through `sendMessage` or, if the phone is not reachable, `updateApplicationContext` (background path documented in APPLE_WATCH_INTEGRATION.md).
  - Replies to `getCurrentMetrics` pings, providing the live HR/HRV overlays that `SleepTrackingView` surfaces in the "📡 Receiving live data" banner.
- **Watch UI**: `DreamWeaver Watch App/ContentView` surfaces the simplified start/stop experience called out in WATCH_APP_SETUP.md, reflecting connectivity and cardio stats.

## 4. iPhone UI Surfaces
- `ContentView`: Implements Instruction.md section "Home Screen – Dream Dashboard" with the hero CTA, last dream preview (color palette, duration, REM), and history list.
- `SleepTrackingView`: Recreates the layout described in APPLE_WATCH_INTEGRATION.md with status badge, timers, HR/HRV indicators, and AI processing banner.
- `DreamDetailView`: Aligns with the doc's post-sleep expectations by showing visualization controls, heart-rate/HRV charts (`HeartRateChartView`, `HRVChartView`), biosignal summary, AI interpretation card, and notes.
- `AIEnhancedVisualizationView` & fallback `DreamVisualizationView`: Translate AI_DREAM_GUIDE.md's art direction—mood-based gradients, particle systems, symbolic orbs, theme tags, intensity/lucidity indicators—into live SwiftUI animations.

## 5. AI Interpretation Pipeline
- `AIDreamService` builds the structured prompt defined in AI_DREAM_GUIDE.md (explicit instructions about mood, themes, visual prompt, intensity, consciousness, symbolism).
- Provider modes:
  - **OpenAI**: Calls `gpt-4o-mini` with `response_format: json_object`, matching configuration directions. Requires API key injection (via `AIConfig.apiKey`).
  - **Anthropic**: Targets `claude-3-5-sonnet-20241022`, enforces JSON-only replies, and obeys header requirements.
  - **Local fallback**: Mirrors the guide's heuristic rules (HRV/movement thresholds) to ensure offline functionality.
- Results populate `SleepData` so downstream views render narratives, tags, and metrics without additional formatting code.

## 6. Charts & Visualization
- `HeartRateChartView` and `HRVChartView` implement the timeline visuals promised in APPLE_WATCH_INTEGRATION.md: gradient line + area charts, average/min/max stats, selectable points, and empty state messaging for watchless sessions.
- Visualization previews honor mood-based palettes from `SleepData.generateDreamColors`, keeping Instruction.md's "dream trends" and AI guide themes cohesive.

## 7. Conformance Gaps & Next Steps
- **Ambient sound analysis**: Instruction.md mentions ambient noise capture; the model stores `ambientNoiseLevel` but no recorder currently feeds it. Bridge with AVAudioEngine or reuse HealthKit environmental audio APIs.
- **Movement & REM sourcing**: Watch integration now streams HR/HRV only; movement intensity and sleep stages are still simulated. Integrate accelerometer / motion samples and, when available, `HKCategoryType.sleepAnalysis` to replace random values.
- **Visualization rendering**: Instruction.md envisions video generation (Metal / SceneKit). Current implementation delivers particle-based SwiftUI animation—sufficient for MVP but not full "AI animation" yet.
- **Watch app install detection**: Due to packaging quirks noted in Instruction.md (appex wrapper), `WatchConnectivityManager` assumes installation when reachable. Once the bundle embedding is finalized, revisit the detection logic to rely on `session.isWatchAppInstalled`.
- **AI provider defaults**: `AIDreamService` initializer currently defaults to `.openAI`. Ensure the production entry point instantiates with `AIConfig.defaultProvider` to keep the local-first behavior promoted in AI_DREAM_GUIDE.md.
- **HealthKit authorization states**: `WorkoutManager` logs errors but does not surface them to the Watch UI. Consider piping failures to `ContentView`'s alert flow so users understand why HR remains zero.

## 8. Testing & Operational Notes
- Latest watchOS build (Watch Ultra 3 target) succeeded via `xcodebuild` after simplifying the Watch UI, aligning with WATCH_APP_SETUP.md troubleshooting steps.
- Install & launch scripts (`build_watch.sh`, `install_watch_app.sh`, etc.) remain available for manual deployment, but the connectivity layer now allows on-device start/stop flows per documentation.

This document should stay alongside the specification files in `Doc/` to keep the living codebase and design doctrine synchronized.
