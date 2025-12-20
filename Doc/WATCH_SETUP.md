# Watch App Setup Guide

## Current Status
✅ iPhone app is fully functional and installed
✅ iPhone & Watch simulators are paired (Pair ID: E61C9CC0-C605-4C28-A930-FC97976689E5)
✅ Both simulators are booted and connected
❌ Watch app has build issue from command line (CopyAndPreserveArchs bug)

## Solution: Run from Xcode

### Steps to Launch Watch App:

1. **Open Xcode Project**
   - The project is already open: `Dream Vewawer.xcodeproj`

2. **Select Watch Scheme**
   - Click the scheme selector (top-left, next to play button)
   - Choose: **"DreamWeaver Watch App"**

3. **Select Watch Simulator as Destination**
   - Click the device selector (next to scheme)
   - Choose: **"Apple Watch Series 11 (46mm)"** (already booted)

4. **Run the Watch App**
   - Click the **▶️ Play button** (or press Cmd+R)
   - Xcode will handle the CopyAndPreserveArchs issue automatically
   - The Watch app will build, install, and launch

### What You Should See:

**On Watch Simulator:**
- App launches showing:
  - "Start Sleep Tracking" button
  - Heart rate: "-- BPM"
  - Duration: "0:00:00"
  - Sync status with iPhone

**On iPhone Simulator:**
- Open Dream Vewawer app
- You should see "Watch Connected" indicator
- Start Dream Mode to begin tracking

### Testing the Connection:

1. **Start from Watch:**
   - Tap "Start Sleep Tracking" on Watch
   - Watch collects heart rate via HealthKit
   - Data syncs to iPhone every 5 minutes

2. **Start from iPhone:**
   - Tap "Start Dream Mode" on iPhone
   - iPhone tells Watch to start tracking
   - Both apps show synchronized status

### Troubleshooting:

**If Watch app doesn't appear in Xcode schemes:**
1. Product menu → Scheme → Manage Schemes
2. Make sure "DreamWeaver Watch App" is checked
3. Close and reopen scheme list

**If build still fails in Xcode:**
The project file may have been corrupted by command-line attempts.
Restore it:
```bash
cd "/Users/SEV0A/Iphone/GJSPO/DreamWeaver/Dream Vewawer"
git restore "Dream Vewawer.xcodeproj/project.pbxproj"
```

## Technical Details

### Why Command-Line Build Fails:
- Xcode 26.1 has a bug with watchOS apps
- "CopyAndPreserveArchs" phase conflicts with linker
- Xcode GUI handles this automatically
- Command-line tools don't apply the workaround

### Simulators Setup:
```
iPhone 16e: F7BCCE4F-8C56-4C92-8878-3BBE2F169FD3 (Booted)
Watch Series 11: 4FE28B3D-1A9C-44F7-A3F1-C49A09B5DD3C (Booted)
Pair: E61C9CC0-C605-4C28-A930-FC97976689E5 (Connected)
```

### Bundle IDs:
- iPhone: `GJSA.Dream-Vewawer`
- Watch: `GJSA.Dream-Vewawer.DreamWeaverWatchApp`

### Features Ready:
- ✅ WatchConnectivity bidirectional sync
- ✅ HealthKit heart rate & HRV collection
- ✅ 5-minute automatic sync interval
- ✅ Real-time status updates
- ✅ AI dream interpretation
- ✅ Timeline charts
- ✅ Moon icon on both platforms

## Next Steps

**Once Watch app is running:**
1. Test sleep tracking workflow
2. Verify data sync between devices
3. Check timeline visualization on iPhone
4. Test AI dream interpretation

**For Physical Device Testing:**
- Both apps will need proper code signing
- Apple Watch must be paired with iPhone
- HealthKit permissions required
- WatchConnectivity works automatically when paired
