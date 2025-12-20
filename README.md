# DreamWeaver Dual-Platform Prototype

This workspace contains SwiftUI source code for both the iPhone and Apple Watch surfaces described throughout `Doc/`.

## Structure

```
Doc/        # Product requirement docs (already provided)
Ihpone/     # iOS SwiftUI prototype
Iwatch/     # watchOS SwiftUI prototype
```

Use these folders as the basis for two Xcode targets inside one workspace. Drag the files into their respective targets, enable HealthKit + WatchConnectivity capabilities, and run on paired simulators to preview the full experience.

## Quick Start

1. **iPhone:** open the *App* template in Xcode, delete the generated files, and import everything from `Ihpone/`. Run on an iOS 17 simulator to explore the dashboard, tracker sheet, detail view, and visualization.
2. **Watch:** add a watchOS target to the same project, replace the template with the files from `Iwatch/`, enable HealthKit/Background Modes, and run on a paired watch simulator.
3. **Link:** promote any shared managers (e.g., WatchConnectivity) into a cross-target group when you embed these files inside a single `.xcodeproj`.

Detailed per-target notes live inside `Ihpone/README.md` and `Iwatch/README.md`.
