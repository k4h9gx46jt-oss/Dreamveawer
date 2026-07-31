# DreamWeaver — Executive Summary

**One-paragraph version:** DreamWeaver is an iPhone + Apple Watch app that records
a night of biosignals, detects REM windows, and synthesises a short film and an
original score from what it measured. Everything runs on-device. The intended
business model is a one-time premium purchase, not a subscription.

For detail, start with [STATUS.md](STATUS.md).

---

## Positioning

DreamWeaver is **not** a sleep tracker. It does not compete with AutoSleep, Pillow
or Apple's Sleep app on accuracy and would lose that fight. It is an instrument
that turns physiology into a keepable artifact.

> *"Your mind paints while you sleep. DreamWeaver reveals the masterpiece."*

---

## How it works

| Stage | Device | What happens |
| --- | --- | --- |
| Before bed | iPhone or Watch | Start Dream Mode from either device |
| Overnight | Watch | `HKWorkoutSession` records 12 biosignals; samples stream to the phone every 5 s |
| Overnight | Watch | `REMClassifier` labels each sample light / deep / REM |
| On waking | Either | Stop from either device; both stay in sync |
| Morning | iPhone | REM segments are aggregated into a `REMDreamProfile` |
| Morning | iPhone | A narrative is generated (currently a stub — see below) |
| Morning | iPhone | An MP4 film and a matching score are rendered from the profile |

---

## What works today

- Bidirectional Watch↔iPhone control, including waking a suspended watch app
- Twelve biosignals captured from HealthKit
- Rule-based REM/deep/light staging, unit tested
- **MP4 film generation** — AVAssetWriter, H.264, 1280×720 @ 30 fps, six visual styles
- **Original score generation** — hand-written synthesiser, 44.1 kHz stereo, six genres
- Picture and score are always chosen together so they agree
- Deterministic per-dream seeding: the same night always renders the same way
- Multi-metric charts, dream detail view, film player with waveform
- ~1 250 lines of unit tests

## What does not work today

| Gap | Impact |
| --- | --- |
| **No persistence** | Every recorded session is lost on relaunch. The app ships with two fabricated mock dreams |
| **Narrative engine is a stub** | Text is randomly selected and unrelated to the user's actual sleep |
| **HealthKit entitlement missing** | Authorization fails on real hardware |
| No settings, onboarding, notifications, search, trends, localization | |
| The rendered film is never shareable | The MP4 exists on disk but no UI exposes it |

---

## Technology

| Layer | Implementation |
| --- | --- |
| Biosignals | HealthKit, `HKWorkoutSession`, `HKLiveWorkoutBuilder` |
| Watch runtime | `WKExtendedRuntimeSession`, background refresh, `UserDefaults` restore |
| Transport | WatchConnectivity — messages, application context, batch backfill |
| Sleep staging | Rule-based thresholds on heart rate and HRV |
| Storage | ❌ none |
| Narrative | 🟡 stub |
| Film | AVFoundation + CoreGraphics, procedural |
| Score | Custom DSP — oscillators, resonant low-pass, one-pole filters, ping-pong delay |
| UI | SwiftUI, Swift Charts |

**Zero third-party dependencies.** No SPM, CocoaPods or Carthage. This keeps the
privacy manifest simple and removes supply-chain risk from App Review.

There is no Metal, SceneKit, or diffusion model in the project. The film renderer
is procedural — which is what makes it fast, offline and free to run.

---

## Privacy

Nothing leaves the device. There is no networking code anywhere in the project, no
analytics, and no account system. This is a deliberate product decision that also
makes one-time pricing viable — there is no per-user marginal cost to fund.

---

## Business model

One-time purchase at **$19.99–$29.99** with Family Sharing, backed by a functional
free tier. Rationale and the full feature plan are in
[PRODUCT_ROADMAP.md](PRODUCT_ROADMAP.md).

---

## Known technical challenges

| Challenge | Position |
| --- | --- |
| Simulators provide no real HealthKit data | Physical device testing is mandatory |
| Overnight battery drain | **Unmeasured.** The 5 s push cadence is aggressive; adaptive sampling is planned |
| Render performance on older hardware | Unprofiled |
| WatchConnectivity drop-outs | Handled via application context + batch backfill |
| Media cache growth | No eviction policy yet |

---

## Success metrics

| Metric | Target | Measured? |
| --- | --- | --- |
| Heart-rate accuracy | ±5 bpm | ❌ |
| Overnight watch battery drain | <15% | ❌ **highest risk** |
| Sync reliability | ≥95% | ❌ |
| Overnight crashes | 0 | ❌ |
| App Store rating | ≥4.5★ | ❌ |

---

## Release readiness

**Not submittable.** Blockers are enumerated in
[APP_STORE_CHECKLIST.md](APP_STORE_CHECKLIST.md). The largest are: no persistence,
no HealthKit entitlement, no privacy manifest, a stubbed narrative engine, and an
overnight battery profile that has never been measured on hardware.

---

## Documents

| Document | Purpose |
| --- | --- |
| [STATUS.md](STATUS.md) | What works today — the source of truth |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Module map and data flow |
| [APP_STORE_CHECKLIST.md](APP_STORE_CHECKLIST.md) | Release gate |
| [PRODUCT_ROADMAP.md](PRODUCT_ROADMAP.md) | Features, pricing, localization |
| [DREAMWEAVER_TELJES_ATTEKINTES.md](DREAMWEAVER_TELJES_ATTEKINTES.md) | Full product overview |
| [AI_DREAM_GUIDE.md](AI_DREAM_GUIDE.md) | Media generation pipeline |
| [APPLE_WATCH_INTEGRATION.md](APPLE_WATCH_INTEGRATION.md) | Connectivity protocol |
| [Instruction.md](Instruction.md) | Original vision (historical) |
