# watchOS Roadmap

**Scope:** watchOS-specific backlog. For the product-level plan and monetization
see [PRODUCT_ROADMAP.md](PRODUCT_ROADMAP.md). For current state see
[STATUS.md](STATUS.md).

> This document previously contained an eight-week implementation plan with code
> samples. Phases 1–4 of that plan are complete and the samples no longer match
> the shipped implementation, so they have been replaced with a status table and a
> forward-looking backlog.

---

## 1. Completed

| Item | Notes |
| --- | --- |
| watchOS target in the shared Xcode project | `DreamWeaver WatchKit App` + extension |
| HealthKit authorization request | `WorkoutManager.requestAuthorization()` |
| `HKWorkoutSession` + `HKLiveWorkoutBuilder` | `.other` / `.indoor` |
| Live heart rate and HRV | Real HealthKit reads |
| SpO₂, respiratory rate, environmental audio exposure | Real HealthKit reads |
| Motion / movement capture | Feeds REM segmentation |
| Rule-based REM/deep/light staging | `Shared/REMClassifier.swift`, unit tested |
| Bidirectional start/stop with the iPhone | Either device can drive |
| Live sample streaming + batch backfill | 5 s push cadence |
| Application-context fallback when unreachable | |
| Background wake for a suspended extension | `RemoteCommandStore` + `WKExtension` refresh |
| `WKExtendedRuntimeSession` | Keeps the runtime alive overnight |
| Session restore after watch app relaunch | `UserDefaults`-backed |
| Watch UI: start/stop, live vitals, HR chart, timer | `WatchContentView` |
| Calligraphic wordmark branding | `DreamWeaverWordmark` |

---

## 2. Blockers — must be fixed before any device testing

| Item | Detail |
| --- | --- |
| **HealthKit entitlement missing** | No `.entitlements` file exists for any target. Authorization silently fails on real hardware. See [APP_STORE_CHECKLIST.md](APP_STORE_CHECKLIST.md) §0.1 |
| **`UIBackgroundModes` not declared** | `workout-processing` is required or the system terminates overnight sessions |
| **Authorization failures are invisible** | `WorkoutManager` only `print`s errors; the watch UI shows zeros with no explanation |

---

## 3. Battery — the highest-risk unknown

The product target is **<15% overnight drain**. This has never been measured.

Current configuration is aggressive:

- `scheduledSampleInterval = 1` second
- `pushInterval = 5` seconds
- `WKExtendedRuntimeSession` held open for the whole night

### Planned work

1. Measure. Five full nights on physical hardware, logging battery at start and end.
2. If drain exceeds ~20%, implement **adaptive sampling**:
   - 30–60 s cadence while HR and HRV are stable
   - increase only when the classifier reports REM or a disturbance
   - batch pushes rather than streaming every 5 s
3. Add a hard stop after 12 hours.
4. Warn the user at session start if the watch is below ~30% charge.

---

## 4. Backlog

### 4.1 Bedside Mode

Minimal always-on display for overnight wear: dimmed clock, subtle heart-rate
indicator, no animation. Respect always-on display budgets and Reduce Motion.

### 4.2 Smart Wake

Wake within a user-chosen window at the lightest detected stage, with escalating
haptics. `REMClassifier` already provides the signal. Needs a reliable watch-side
alarm path and a fallback when the watch is off-wrist.

### 4.3 Lucid dream training

REM-timed haptic cues, calibrated not to wake the sleeper. Requires an explicit
consent flow and must be framed as an experience feature, never as therapy. See
[PRODUCT_ROADMAP.md](PRODUCT_ROADMAP.md) §2.4.

### 4.4 Complications

One-tap Dream Mode start from the watch face, plus a "last night" summary
complication.

### 4.5 Improved staging

- Cross-check against `HKCategoryType.sleepAnalysis` where available
- Replace fixed thresholds with a personalised baseline (each user's own resting
  HR and HRV distribution)
- Evaluate a small Core ML classifier once labelled data exists

### 4.6 Real ECG

`ecgConfidence` is currently a placeholder. Reading `HKElectrocardiogram` requires
a Series 4+ and user-initiated capture, so this may remain a manual, on-demand
feature rather than a passive one.

### 4.7 Health app write-back

Publish completed sessions as `HKCategoryTypeIdentifier.sleepAnalysis` so
DreamWeaver data appears alongside Apple's own. Requires the HealthKit *share*
entitlement in addition to *read*.

### 4.8 Standalone watch playback

Play a short version of the dream score on the watch after waking, without
reaching for the phone.

---

## 5. Testing

Meaningful validation requires physical hardware — Apple Watch simulators do not
produce real HealthKit data.

| Scenario | Verified |
| --- | --- |
| Start from iPhone, watch app closed | ❌ |
| Start from watch, iPhone locked | ❌ |
| Stop from either device | ❌ |
| Airplane mode overnight, reconnect on wake | ❌ |
| Watch battery dies mid-session | ❌ |
| Session longer than 12 hours | ❌ |
| HealthKit permission denied | ❌ |
| Watch removed from wrist mid-session | ❌ |

Unit-testable logic lives in `Shared/REMClassifier.swift` and is covered by
`WatchREMClassifierTests`:

```bash
./run-tests.sh --watch
```

---

## 6. Requirements

| Component | Minimum |
| --- | --- |
| watchOS | 11.0 |
| iOS | 26.2 |
| Hardware | Apple Watch with heart-rate sensor |
| Xcode | 26+ |
