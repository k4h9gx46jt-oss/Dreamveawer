# Vision ↔ Implementation Conformance Review

**Last reviewed:** 2026-08-04.

This document compares the original product vision in [Instruction.md](Instruction.md)
with what the code actually does. For a plain status list see [STATUS.md](STATUS.md).

---

## 1. Flow conformance

| Vision step | Implementation | Verdict |
| --- | --- | --- |
| Pre-sleep: arm Dream Mode from the phone | `DreamDashboardView` → `SleepTrackingView` | ✅ matches |
| Watch collects while the phone rests | `WorkoutManager` + `HKWorkoutSession` | ✅ matches |
| Data syncs during the night | `PhoneWatchConnectivityManager`, 5 s cadence | ✅ exceeds — the vision assumed 5 minutes |
| Morning: stop from either device | Bidirectional, with state reconciliation | ✅ matches |
| Symbolic interpretation of the night | `AIDreamService` | ❌ **stub, randomised** |
| Short generated film | `DreamFilmRenderer` produces a real MP4 | ✅ **exceeds the vision** |
| Soundscape from bio rhythm | `DreamScoreRenderer` produces a real score | ✅ **exceeds the vision** |
| Journal with notes and titles | Not implemented | ❌ |
| Private social feed / Dream Gallery | Not implemented | ❌ deliberately deferred |

---

## 2. Data model mapping

`SleepData` carries every metric the vision called for — duration, heart rate, HRV,
movement, REM %, deep %, ambient noise — plus the AI augmentation fields and a
`REMDreamProfile`.

`BiosignalDataPoint` captures twelve signals per sample, considerably more than the
three the vision assumed.

**Divergence:** both are plain `Codable` structs. The vision and earlier docs
assumed SwiftData `@Model` entities with cascade relationships. That code does not
exist, and consequently **nothing is persisted**.

---

## 3. Watch integration chain

- `WatchSideConnectivityManager` activates `WCSession`, reports reachability and
  install state, and pushes snapshots.
- `RemoteCommandStore` queues commands that arrive while the extension is
  suspended and schedules a `WKExtension` background refresh to drain them. This
  was not anticipated by the vision but proved necessary.
- `WorkoutManager` holds a `WKExtendedRuntimeSession` and persists session state
  to `UserDefaults` so an app relaunch resumes rather than loses the night.
- `reconcilePhoneControlState` resolves disagreements between the two devices.

---

## 4. iPhone surfaces

| Vision screen | Implementation |
| --- | --- |
| Dream Dashboard | `DreamDashboardView` — hero CTA, last dream, history |
| Dream Playback | `DreamVideoView` — AVPlayer, scene pager, waveform |
| Dream Journal | ❌ not implemented |
| Dream Gallery | ❌ deliberately deferred |

`SleepTrackingView` and `DreamDetailView` use paged multi-metric charts
(`MultiMetricChart`) rather than the separate heart-rate and HRV charts the earlier
docs described. `HeartRateChartView` and `HRVChartView` never existed.

---

## 5. Interpretation pipeline

The vision described an on-device model producing a symbolic reading of the night.

What exists now:

- `BiosignalHeuristic.analyse(session:)` — a deterministic engine that derives
  mood, narrative, themes, symbolism, intensity, consciousness, and stage
  percentages directly from the session’s `REMDreamProfile` and biosignals.
  The narrative references the actual longest REM window start time and duration,
  measured heart rate and HRV, and their overnight trends. No randomness.
- `FoundationModelDreamOutput` — a `@Generable` struct that receives a biosignal
  summary as a prompt and returns an enriched narrative when Apple Intelligence is
  enabled on the device (`SystemLanguageModel.default.availability == .available`).
  Any failure falls back silently to the heuristic.

Cloud providers remain explicitly ruled out: per-user API cost is incompatible
with one-time pricing. See [PRODUCT_ROADMAP.md](PRODUCT_ROADMAP.md) §1.

---

## 6. Media generation

The vision asked for a 10–30 second abstract animation rendered with Metal or
SceneKit, plus a soundscape.

What exists is more ambitious and built differently:

- A full H.264 MP4 via `AVAssetWriter` and CoreGraphics — no Metal, no SceneKit
- Six visual styles paired 1:1 with six musical genres
- An original score from a hand-written synthesiser, phrase-aligned to REM segments
- Deterministic seeding so a given night always renders identically

Duration is derived from the REM profile rather than fixed at 10–30 seconds.

---

## 7. Conformance gaps

### 7.1 Closed since the last review

| Former gap | Resolution |
| --- | --- |
| Ambient sound never captured | `environmentalAudioExposure` now feeds `noiseExposure` |
| Movement simulated | Real movement data drives REM segmentation |
| REM stages simulated | `REMClassifier` — real, rule-based, unit tested |
| Visualisation was particles only | Real MP4 film generation |
| No soundtrack | Real score generation |
| Watch install detection unreliable | Reachability and install state now reported explicitly |
| AI provider default inconsistency | Moot — no providers exist |
| **Narrative engine was a stub** | `BiosignalHeuristic` + Foundation Models; output now grounded in real biosignals |
| **No persistence** | `Codable` + `FileManager` atomic write; mocks removed; `deleteDream(id:)` added |

### 7.2 Open

| Gap | Severity | Notes |
| --- | --- | --- |
| **No persistence** | 🔴 blocker | In-memory store seeded with two mocks; every session is lost on relaunch |
| **Narrative engine is a stub** | 🔴 blocker | Output unrelated to the user's sleep |
| **HealthKit entitlement missing** | 🔴 blocker | No `.entitlements` file for any target |
| **No `PrivacyInfo.xcprivacy`** | 🔴 blocker | Upload rejected by App Store Connect |
| **No `UIBackgroundModes`** | 🔴 blocker | Overnight sessions terminated by the system |
| iOS target lacks HealthKit usage strings | 🔴 blocker | Runtime crash on first HealthKit call |
| HealthKit auth failures invisible to the user | 🟠 | `WorkoutManager` only `print`s errors |
| No notifications | 🟠 | The vision's morning payoff moment is missing |
| Rendered film never shareable | 🟠 | File exists on disk, no UI exposes it |
| Heuristic "risk" metrics imply clinical meaning | 🟠 | Rejection risk under Guidelines 1.4.1 / 5.1.3 |
| No journal, search, trends or insights | 🟡 | Blocked by the persistence gap |
| No settings, onboarding or empty states | 🟡 | |
| Media cache has no eviction policy | 🟡 | Unbounded disk growth |
| `Item.swift` template leftover | 🟡 | Dead SwiftData model, should be deleted |
| No localization | 🟡 | Strings hardcoded in views |
| Overnight battery unmeasured | 🔴 risk | Target <15%, never validated on hardware |

Full remediation list: [APP_STORE_CHECKLIST.md](APP_STORE_CHECKLIST.md).

---

## 8. Testing

Roughly 1 400 lines of unit tests across nine files.

```bash
./run-tests.sh              # unit tests + watchOS compile check
./run-tests.sh --watch      # sleep-staging suite only
./run-tests.sh --all        # unit and UI tests
```

New suites added with this change:

- **`SleepDataStoreTests`** — disk round-trip, delete, fresh-install empty state, corrupt-file safety.
- **`NarrativeHeuristicTests`** — mood derivation from every metric combination, narrative groundedness (references actual HR/HRV), stage-percentage accuracy from labelled samples and from `REMDreamProfile`, determinism guarantee.

Not covered: connectivity (requires paired hardware), HealthKit reads, battery behaviour, and anything overnight.

---

## 9. Maintenance rule

This project accumulated a large gap between documentation and code — docs
described cloud AI integrations, SwiftData persistence and view files that never
existed, which repeatedly misled debugging.

**Update [STATUS.md](STATUS.md) in the same commit that changes behaviour.**
