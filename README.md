# DreamWeaver

An iPhone + Apple Watch app that records a night of biosignals, detects REM
windows, and synthesises a short film and an original score from what it measured.
Everything runs on-device — no network calls, no accounts, no third-party
dependencies.

> **Status: pre-release.** Core capture and media generation work. Persistence, a
> real narrative engine and App Store compliance do not. See
> [Doc/STATUS.md](Doc/STATUS.md).

---

## Repository layout

```
Shared/     REMClassifier — compiled into both platform targets
Ihpone/     iOS sources + the Xcode project
Iwatch/     watchOS sources
Doc/        Documentation
```

The Xcode project at `Ihpone/DreamWeaver/DreamWeaver.xcodeproj` owns all five
targets and references sources from all three source folders.

| Target | Platform |
| --- | --- |
| `DreamWeaver` | iOS 26.2 |
| `DreamWeaver WatchKit App` | watchOS 11.0 |
| `DreamWeaver WatchKit Extension` | watchOS 11.0 |
| `DreamWeaverTests` | iOS |
| `DreamWeaverUITests` | iOS |

---

## Getting started

```bash
open Ihpone/DreamWeaver/DreamWeaver.xcodeproj
```

Or use the helper scripts from the repository root:

| Script | Purpose |
| --- | --- |
| `./run-tests.sh` | Unit tests plus a watchOS compile check |
| `./run-tests.sh --watch` | Sleep-staging suite only |
| `./run-tests.sh --all` | Unit and UI tests |
| `./run-tests.sh --filter <Suite>` | Run one suite or one test |
| `./start-dreamweaver.sh` | Boot simulators, build, launch |
| `./test-and-start.sh` | Test, then launch if green |
| `./reinstall.sh` | Clean reinstall on booted simulators |

Override the simulator with `DREAMWEAVER_IOS_SIM_NAME="iPhone 17"`.

> **Simulators cannot provide real HealthKit data.** Anything sensor- or
> battery-related must be tested on a physical iPhone and Apple Watch.

---

## What works

- Bidirectional Watch↔iPhone control, including waking a suspended watch app
- Twelve biosignals from HealthKit, sampled every second
- Rule-based REM / deep / light staging, unit tested
- **MP4 film generation** — `AVAssetWriter`, H.264, 1280×720 @ 30 fps, six visual styles
- **Original score generation** — hand-written synthesiser, 44.1 kHz stereo, six genres
- Picture and score always selected together so they agree
- Deterministic per-dream seeding
- Multi-metric charts, dream detail view, film player with waveform
- ~1 250 lines of unit tests

## What does not work

| Gap | Impact |
| --- | --- |
| No persistence | Sessions lost on relaunch; the app ships with two mock dreams |
| Narrative engine is a stub | Text is randomised and unrelated to actual sleep |
| HealthKit entitlement missing | Authorization fails on real hardware |
| No privacy manifest, no background modes | Cannot be submitted |
| No settings, onboarding, notifications, search, trends, localization | |
| Rendered film is never shareable | The MP4 exists on disk but no UI exposes it |

---

## Testing

```bash
./run-tests.sh
```

| Suite | Covers |
| --- | --- |
| `DreamScoreTests` | Musical phrase structure, tempo, genre selection |
| `DreamMediaCompositionTests` | Composer orchestration, prompt building |
| `DreamSessionTests` | Session lifecycle, averages, REM profiling |
| `DreamFilmTests` | Visual profile derivation, renderer configuration |
| `WatchREMClassifierTests` | Sleep-stage rules and window accumulation |
| `DreamWeaverUITests` | Launch smoke tests |

---

## Documentation

| Document | Purpose |
| --- | --- |
| [Doc/STATUS.md](Doc/STATUS.md) | **Start here** — what works today |
| [Doc/ARCHITECTURE.md](Doc/ARCHITECTURE.md) | Module map and data flow |
| [Doc/APP_STORE_CHECKLIST.md](Doc/APP_STORE_CHECKLIST.md) | Release blockers |
| [Doc/PRODUCT_ROADMAP.md](Doc/PRODUCT_ROADMAP.md) | Features, pricing, localization |
| [Doc/AI_DREAM_GUIDE.md](Doc/AI_DREAM_GUIDE.md) | Media generation pipeline |
| [Doc/APPLE_WATCH_INTEGRATION.md](Doc/APPLE_WATCH_INTEGRATION.md) | Connectivity protocol |
| [Doc/APPLE_WATCH_ROADMAP.md](Doc/APPLE_WATCH_ROADMAP.md) | watchOS backlog |
| [Doc/WATCH_SETUP.md](Doc/WATCH_SETUP.md) | Building and running the watch target |
| [Doc/WATCH_APP_SETUP.md](Doc/WATCH_APP_SETUP.md) | Capability configuration |
| [Doc/DreamWeaverApp-CompleteOverview.md](Doc/DreamWeaverApp-CompleteOverview.md) | Executive summary |
| [Doc/DREAMWEAVER_TELJES_ATTEKINTES.md](Doc/DREAMWEAVER_TELJES_ATTEKINTES.md) | Full product overview |
| [Doc/Instruction.md](Doc/Instruction.md) | Original vision (historical) |
| [Doc/process.md](Doc/process.md) | Vision ↔ implementation conformance review |

**Documentation is English-only.** In-app localization is planned separately — see
[Doc/PRODUCT_ROADMAP.md](Doc/PRODUCT_ROADMAP.md) §5.

> **Maintenance rule:** update [Doc/STATUS.md](Doc/STATUS.md) in the same commit
> that changes behaviour. This repository previously accumulated a large gap
> between its documentation and its code.
