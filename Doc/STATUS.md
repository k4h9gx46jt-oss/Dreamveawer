# DreamWeaver — Implementation Status

**Last verified:** 2026-08-04

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
| Movement / motion | ✅ | `MotionManager`, CoreMotion accelerometer at 1 Hz, normalised to `0...1` |
| Session persistence across watch app relaunch | ✅ | `UserDefaults`-backed, see `WorkoutManager.restorePersistedSessionIfNeeded()` |
| Background wake when the watch app is closed | ✅ | `RemoteCommandStore` + `WKExtension` background refresh |
| **Automatic Dream Mode start** | ✅ | `SleepAutoStartMonitor` — see §2.1 |

**Sampling cadence:** `pushInterval = 5` seconds, `scheduledSampleInterval = 1` second.
Older docs claimed 5 *minutes* — that has never matched the shipped code.
This cadence is aggressive and is a **known battery risk** (see
[APP_STORE_CHECKLIST.md](APP_STORE_CHECKLIST.md)).

---

## 2. Sleep staging

| Capability | Status | Notes |
| --- | --- | --- |
| Rule-based REM/deep/light classifier | ✅ | `Shared/REMClassifier.swift`, unit tested |
| `awake` stage | ✅ | Movement above `0.55` overrides every sleep stage |
| Personalised thresholds | ✅ | `SleepBaseline` tracks the sleeper's own resting floor and typical HRV |
| Movement veto on REM | ✅ | REM requires muscle atonia, so a restless wrist rules it out |
| Temporal smoothing | ✅ | 7-sample majority vote stops 1 Hz sampling flipping the stage every second |
| REM window accumulation | ✅ | `REMWindow`, extended while REM persists |
| Stage transported to the phone | ✅ | `remState` on live samples **and** in the `sleepEnd` payload |
| `REMDreamProfile` / `REMSegment` aggregation | ✅ | 60 s buckets driven by the recorded stage, majority vote per bucket |
| Guaranteed profile when samples exist | ✅ | A nil profile makes film generation throw, so one segment is always produced |
| Machine-learning sleep staging | ❌ | Still deterministic rules, now personalised |
| `HKCategoryType.sleepAnalysis` cross-check | 🟡 | Read for auto-start, not yet used to correct staging |

Default (population) thresholds, used until the baseline warms up after 60 readings:

- Heart rate `< 50` → `deep`
- Heart rate in `50...75` **and** HRV `>= 35` → `rem`
- Otherwise → `light`

Once warmed up these become relative to the sleeper: deep below `resting × 0.97`,
REM inside `resting × 0.97 ... resting × 1.28` with HRV above `typical × 0.75`.
This was the fix for fixed thresholds mis-staging anyone whose resting rate is not
near 60 bpm.

`REMClassifier.Configuration.legacy` preserves the original single-reading
behaviour; the watch runs `.overnight`.

### 2.1 Automatic start

`SleepAutoStartMonitor` arms Dream Mode without a button press. Either trigger is
sufficient:

1. **The system reports sleep.** An `HKObserverQuery` on `sleepAnalysis` with
   background delivery wakes the extension when watchOS records an `asleep*`
   sample.
2. **Our own readings agree inside the sleep window.** `SleepOnsetDetector`
   requires sustained low motion *and* a heart rate at or below the resting
   baseline. Both are needed — lying still while reading is not sleep.

The nightly window is inferred from the user's existing Health app history
(`SleepWindow.inferred(from:)`, circular mean over the last 14 nights), so the
bedtime never has to be entered twice. Heart-rate polling only runs inside that
window.

| Capability | Status |
| --- | --- |
| Auto-start from system sleep detection | ✅ |
| Auto-start from own biosignals inside the window | ✅ |
| Sleep window inferred from Health history | ✅ |
| User override of the inferred window | ❌ no settings UI yet |
| Auto-**stop** on waking | ❌ |

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

| Capability | Status | Notes |
| --- | --- | --- |
| Narrative, themes, symbolism, intensity, consciousness | ✅ | Biosignal-derived, deterministic |
| Cloud AI provider | ❌ | Explicitly ruled out — incompatible with one-time pricing |
| On-device language model (Foundation Models) | ✅ | `LanguageModelSession` + `@Generable` output; device-capability-gated |
| Deterministic biosignal heuristic | ✅ | `BiosignalHeuristic` — primary path and Foundation Models fallback |

`AIDreamService.interpret(session:)` now operates in two stages:

1. **`BiosignalHeuristic.analyse(session:)`** always runs. Derives mood, intensity,
   consciousness, REM/deep estimates, narrative, themes, and symbolism directly
   from `REMDreamProfile` metrics and real biosignals. The narrative references
   the actual longest REM window time, measured HR/HRV values, and their trends.
2. **Foundation Models enrichment** runs on top when
   `SystemLanguageModel.default.availability == .available` (Apple Intelligence
   enabled on the device). A `@Generable FoundationModelDreamOutput` struct
   receives a biosignal summary prompt and returns a richer narrative, themed
   vocabulary, and visual prompt. Any failure silently falls back to the heuristic.

REM % and deep-sleep % are now computed from stage-labelled samples when the
watch transported them; otherwise derived from `REMDreamProfile.totalDuration`.

**The narrative a user reads is now grounded in their actual sleep data.**

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
| **Share the rendered MP4** | ✅ | `ShareLink` exposes the film + score in `DreamVideoView` (`DreamVideoResult.shareableItems`) |
| **Persistence** | ✅ | `Codable` + `FileManager`, atomic write to Application Support |
| Settings screen | ❌ | |
| Onboarding / permission priming | ✅ | `OnboardingView` first-run flow primes HealthKit; `HealthAccessBanner` handles unavailable/not-granted |
| Local notifications ("your dream is ready") | ❌ | No `UNUserNotificationCenter` usage anywhere |
| Search / filter the journal | ❌ | |
| Trend analysis across nights | ❌ | |
| Localization | ❌ | English strings hardcoded in views |

---

## 7. Persistence

`SleepDataStore` now persists to disk on every mutation:

- `init()` calls `loadFromDisk()` — on a fresh install the list starts empty (no more fabricated mocks).
- `addDream(from:aiResult:)` calls `saveToDisk()` after inserting.
- `deleteDream(id:)` removes by UUID and calls `saveToDisk()` (also satisfies the GDPR deletion requirement).
- Storage path: `Application Support/DreamWeaver/dreams.json`.
- Write uses `.atomic` to prevent corruption on crash.
- `SleepData` is `Codable`; no model changes were required.

The unused Xcode SwiftData template `Ihpone/DreamWeaver/DreamWeaver/Item.swift` still needs to be deleted (see [APP_STORE_CHECKLIST.md](APP_STORE_CHECKLIST.md) §0.6).

---

## 8. Testing

| Suite | Lines | Covers |
| --- | --- | --- |
| `DreamScoreTests` | 319 | Musical phrase structure, tempo, genre selection |
| `DreamMediaCompositionTests` | 226 | Composer orchestration, prompt building |
| `SleepAutoStartTests` | 232 | Sleep window arithmetic, schedule inference, onset detection |
| `REMProfileTests` | 175 | Stage-driven segmentation, guaranteed profile, transport round trips |
| `DreamSessionTests` | 213 | Session lifecycle, averages, REM profiling |
| `DreamFilmTests` | 181 | Visual profile derivation, renderer configuration |
| `WatchREMClassifierTests` | 300 | Staging rules, personalised baseline, movement, smoothing |
| `DreamFixture` | 109 | Shared test data |
| `DreamWeaverUITests` | 74 | Launch smoke tests |
| `SleepDataStoreTests` | — | Disk persistence round-trip, delete, fresh-install empty state |
| `NarrativeHeuristicTests` | — | Mood derivation, narrative groundedness, stage-percentage accuracy |
| `ReleaseConfigurationTests` | — | iOS/watch entitlements, Health usage strings, privacy manifest, iOS `audio` background mode |
| `PhoneWatchConnectivityTests` | — | Sample decoding, de-duplication, REM window transitions |
| `DreamShareTests` | — | Film-before-score share ordering; empty when nothing rendered |
| `HealthAccessStateTests` | — | Health availability/permission resolution and banner descriptors |
| `OnboardingGateTests` | — | First-run gating and storage-key stability |
| `DreamDashboardModelTests` | — | Dashboard empty-state rule |

191 tests pass (`./run-tests.sh`). Run with [`run-tests.sh`](../run-tests.sh).

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

**Device/App Store build configuration:**

- `PrivacyInfo.xcprivacy` present and bundled — declares Health & Fitness (App Functionality, unlinked, untracked) and the `UserDefaults` required-reason API (`CA92.1`).
- iOS app `UIBackgroundModes` declares `audio` (dream soundtrack playback) via `Ihpone/DreamWeaver/Info.plist`, merged with the generated Info.plist keys.

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
