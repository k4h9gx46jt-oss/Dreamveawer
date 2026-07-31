# DreamWeaver — Implementation Status

**Last verified:** 2026-07-31 (against commit `9b3eae6`)

This is the **single source of truth** for what the codebase actually does today.
Every other document in `Doc/` describes either the original product vision
(`Instruction.md`) or a specific subsystem. When they disagree with this file,
this file wins.

> **Maintenance rule:** update this file in the same commit that changes behaviour.
> Historically the docs drifted far ahead of the code, which cost real debugging time.

---

## Legend

| Symbol | Meaning |
| --- | --- |
| ✅ | Implemented and working |
| 🟡 | Partially implemented — usable but incomplete |
| ❌ | Not implemented (documented as a goal only) |

---

## 1. Data capture (Apple Watch)

| Capability | Status | Notes |
| --- | --- | --- |
| `HKWorkoutSession` background tracking | ✅ | `.other` / `.indoor`, `HKLiveWorkoutBuilder` |
| `WKExtendedRuntimeSession` | ✅ | Keeps the runtime alive beyond normal watch app limits |
| Heart rate | ✅ | Live from HealthKit |
| Heart rate variability (SDNN) | ✅ | Live from HealthKit |
| SpO₂ | ✅ | Live from HealthKit |
| Respiratory rate | ✅ | Live from HealthKit |
| Environmental audio exposure | ✅ | Feeds `noiseExposure` |
| Wrist temperature delta | 🟡 | Field is captured and transported; values are partly synthesised |
| ECG confidence | 🟡 | Synthesised placeholder, not a real `HKElectrocardiogram` read |
| Hypertension risk | 🟡 | Derived heuristic, **not a clinical measurement** |
| Apnea risk | 🟡 | Derived heuristic, **not a clinical measurement** |
| Sleep score | 🟡 | Derived heuristic |
| Movement / motion | ✅ | Drives REM segmentation |
| Session persistence across watch app relaunch | ✅ | `UserDefaults`-backed, see `WorkoutManager.restorePersistedSessionIfNeeded()` |
| Background wake when the watch app is closed | ✅ | `RemoteCommandStore` + `WKExtension` background refresh |

**Sampling cadence:** `pushInterval = 5` seconds, `scheduledSampleInterval = 1` second.
Older docs claimed 5 *minutes* — that has never matched the shipped code.
This cadence is aggressive and is a **known battery risk** (see
[APP_STORE_CHECKLIST.md](APP_STORE_CHECKLIST.md)).

---

## 2. Sleep staging

| Capability | Status | Notes |
| --- | --- | --- |
| Rule-based REM/deep/light classifier | ✅ | `Shared/REMClassifier.swift`, unit tested |
| REM window accumulation | ✅ | `REMWindow`, extended while REM persists |
| `REMDreamProfile` / `REMSegment` aggregation | ✅ | 60 s buckets, dominant-driver detection |
| Machine-learning sleep staging | ❌ | Currently pure thresholds on HR + HRV |
| `HKCategoryType.sleepAnalysis` cross-check | ❌ | Apple's own staging is never read back |

Classifier thresholds (`REMClassifier`):

- Heart rate `< 50` → `deep`
- Heart rate in `50...75` **and** HRV `>= 35` → `rem`
- Otherwise → `light`

---

## 3. Watch ↔ iPhone connectivity

| Capability | Status |
| --- | --- |
| Start Dream Mode from iPhone → watch begins tracking | ✅ |
| Start Dream Mode from watch → iPhone reflects it | ✅ |
| Stop from either device, both stay in sync | ✅ |
| Live sample streaming while tracking | ✅ |
| Batched sample delivery / backfill | ✅ |
| Reachability + install-state reporting | ✅ |
| Application-context fallback when unreachable | ✅ |
| Command replay when the watch app is not running | ✅ |

Message vocabulary is documented in [APPLE_WATCH_INTEGRATION.md](APPLE_WATCH_INTEGRATION.md).

---

## 4. Dream media generation

This is the **most capable and least documented** part of the project.

| Capability | Status | Notes |
| --- | --- | --- |
| MP4 dream film | ✅ | `DreamFilmRenderer`, AVAssetWriter, H.264, 1280×720 @ 30 fps |
| Six distinct visual styles | ✅ | `auroraCathedral`, `pastoralDrift`, `stellarNebula`, `stormHorizon`, `emberTempest`, `fracture` |
| Procedural soundtrack | ✅ | `DreamScoreRenderer`, 44.1 kHz stereo CAF |
| Six musical genres | ✅ | `symphonic`, `chamber`, `celestial`, `cinematic`, `hardRock`, `industrial` |
| Genre ↔ visual style coupling | ✅ | Picture and score always agree |
| Per-dream deterministic variation | ✅ | Seeded `DreamRandom` |
| Waveform extraction for UI | ✅ | Rendered under the video player |
| Media caching on disk | ✅ | `DreamMediaCache` |
| Render progress reporting | ✅ | `progressHandler` |
| **Generative / diffusion-model video** | ❌ | The renderer is fully procedural. It is *not* an AI image model. |

The output is genuinely novel per session because it is driven by the real
`REMDreamProfile` (intensity, mood polarity, apnea/noise spikes, HR/HRV trend).

---

## 5. Dream interpretation (narrative text)

| Capability | Status |
| --- | --- |
| Narrative, themes, symbolism, intensity, consciousness | 🟡 **Stub only** |
| Cloud AI provider | ❌ Not implemented |
| On-device language model | ❌ Not implemented |
| Deterministic biosignal heuristic | ❌ Not implemented |

`AIDreamService.interpret(session:)` currently returns:

- a **randomly selected** `DreamMood`
- one of **six hardcoded narrative strings**
- `Double.random` values for intensity, consciousness, REM % and deep-sleep %
- randomly shuffled themes and symbols from fixed pools

**Consequence:** the narrative a user reads is unrelated to how they slept.
This is the single biggest correctness gap in the product and is a release
blocker — see [PRODUCT_ROADMAP.md](PRODUCT_ROADMAP.md).

> Earlier revisions of the docs described OpenAI and Anthropic integrations,
> API-key configuration and a local heuristic engine. **None of that code has
> ever existed in this repository.** Those claims have been removed.

---

## 6. iPhone application

| Capability | Status | Notes |
| --- | --- | --- |
| Dream dashboard with history list | ✅ | |
| Live tracking screen with paged charts | ✅ | |
| Multi-metric biosignal charts | ✅ | `MultiMetricChart` |
| Dream detail view | ✅ | |
| Dream film player + scene pager + waveform | ✅ | `DreamVideoView` |
| Particle visualisation (legacy path) | ✅ | `ParticleEngine`, 60 particles |
| Calligraphic wordmark branding | ✅ | Great Vibes, both platforms |
| Share dream narrative as text | ✅ | `ShareLink` in `DreamDetailView` |
| **Share the rendered MP4** | ❌ | The file exists on disk but is never exposed |
| **Persistence** | ❌ | See below |
| Settings screen | ❌ | |
| Onboarding / permission priming | ❌ | |
| Local notifications ("your dream is ready") | ❌ | No `UNUserNotificationCenter` usage anywhere |
| Search / filter the journal | ❌ | |
| Trend analysis across nights | ❌ | |
| Localization | ❌ | English strings hardcoded in views |

---

## 7. Persistence — known critical gap

`SleepDataStore` is an in-memory `ObservableObject`:

```swift
@Published private(set) var dreams: [SleepData] = [
    SleepData.mock(),
    SleepData.mock(durationHours: 2.3)
]
```

Consequences:

- Every launch shows two **fabricated** dreams that the user never recorded.
- Every real recorded session is **lost** when the app terminates.
- Trend analysis, journals and history are impossible to build on top.

`SleepData` is a `Codable struct`, **not** a SwiftData `@Model`. The only
SwiftData usage in the repository is the unused Xcode template file
`Ihpone/DreamWeaver/DreamWeaver/Item.swift`, which should be deleted.

---

## 8. Testing

| Suite | Lines | Covers |
| --- | --- | --- |
| `DreamScoreTests` | 319 | Musical phrase structure, tempo, genre selection |
| `DreamMediaCompositionTests` | 226 | Composer orchestration, prompt building |
| `DreamSessionTests` | 213 | Session lifecycle, averages, REM profiling |
| `DreamFilmTests` | 181 | Visual profile derivation, renderer configuration |
| `WatchREMClassifierTests` | 180 | Sleep-stage rules and window accumulation |
| `DreamFixture` | 109 | Shared test data |
| `DreamWeaverUITests` | 74 | Launch smoke tests |

Run with [`run-tests.sh`](../run-tests.sh). See [TESTING section in the root README](../README.md).

---

## 9. Build configuration

| Setting | Value |
| --- | --- |
| iOS deployment target | 26.2 |
| watchOS deployment target | 11.0 |
| Swift version | 5.0 |
| Marketing version | 1.0 |
| Build number | 1 |
| iPhone bundle ID | `GJDRW.DreamWeaver` |
| Watch app bundle ID | `GJDRW.DreamWeaver.watchkitapp` |
| Watch extension bundle ID | `GJDRW.DreamWeaver.watchkitapp.watchkitextension` |
| Code signing | Automatic, team `28TCC8Y78C` |

**Missing and required for device/App Store builds:**

- No `.entitlements` file exists for any target → the HealthKit capability is
  **not enabled**, so authorization silently fails on real hardware.
- The iOS target declares **no** `NSHealthShareUsageDescription` /
  `NSHealthUpdateUsageDescription`. Only the watch extension Info.plist has them.
- No `PrivacyInfo.xcprivacy` privacy manifest.
- No `UIBackgroundModes` declaration.

Full list: [APP_STORE_CHECKLIST.md](APP_STORE_CHECKLIST.md).

---

## 10. Document map

| Document | Purpose |
| --- | --- |
| `STATUS.md` (this file) | What works today |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Module map and data flow |
| [`APP_STORE_CHECKLIST.md`](APP_STORE_CHECKLIST.md) | Release-readiness gate |
| [`PRODUCT_ROADMAP.md`](PRODUCT_ROADMAP.md) | Feature and monetization plan |
| [`AI_DREAM_GUIDE.md`](AI_DREAM_GUIDE.md) | Media generation pipeline in depth |
| [`APPLE_WATCH_INTEGRATION.md`](APPLE_WATCH_INTEGRATION.md) | Connectivity protocol |
| [`APPLE_WATCH_ROADMAP.md`](APPLE_WATCH_ROADMAP.md) | watchOS-specific backlog |
| [`WATCH_SETUP.md`](WATCH_SETUP.md) | Building and running the watch target |
| [`WATCH_APP_SETUP.md`](WATCH_APP_SETUP.md) | Capability configuration |
| [`Instruction.md`](Instruction.md) | Original product vision (historical) |
| [`process.md`](process.md) | Vision ↔ implementation conformance review |
| [`DreamWeaverApp-CompleteOverview.md`](DreamWeaverApp-CompleteOverview.md) | Executive summary |
| [`DREAMWEAVER_TELJES_ATTEKINTES.md`](DREAMWEAVER_TELJES_ATTEKINTES.md) | Full product overview |
