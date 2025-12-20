# Apple Watch Integration Guide

## Overview
DreamWeaver now features **full Apple Watch integration** for real-time physiological data collection during sleep. Start and stop sleep tracking from either iPhone or Apple Watch, with live biosignal data syncing automatically between devices.

## 🎯 Key Features

### ⌚️ **Apple Watch App**
- **Start/Stop sleep tracking** directly from your wrist
- **Live heart rate monitoring** with HealthKit
- **HRV calculation** for sleep quality analysis
- **Real-time sync** to iPhone every 5 minutes
- **Background data transfer** when iPhone not reachable
- **Workout session** integration for continuous tracking

### 📱 **iPhone App Enhancements**
- **Watch connection status** indicator
- **Live biosignal display** from Watch during tracking
- **Heart rate timeline charts** with 5-minute intervals
- **HRV trend graphs** throughout sleep session
- **Automatic data synchronization** via WatchConnectivity
- **Fallback to simulated data** when Watch unavailable

### 📊 **Data Collection**
- **Heart Rate**: Collected continuously from Apple Watch sensors
- **HRV (Heart Rate Variability)**: Calculated from HR intervals
- **Timeline Storage**: Data points saved every 5 minutes
- **Historical Graphs**: View complete HR/HRV trends after waking
- **Persistent Storage**: All data saved with SwiftData

## 🚀 How to Use

### Option 1: Start from Apple Watch (Recommended)
1. **Open DreamWeaver app on Watch**
2. Tap **"Start"** button
3. **HealthKit permission** will be requested (first time only)
4. Watch begins tracking heart rate and HRV
5. **Syncs to iPhone every 5 minutes** automatically
6. When ready to wake, tap **"Stop"** on Watch
7. **View data on iPhone** with detailed charts

### Option 2: Start from iPhone
1. **Open DreamWeaver app on iPhone**
2. Tap **"Start Dream Mode"**
3. If Watch is connected, it **automatically starts tracking**
4. iPhone shows **live HR/HRV from Watch** (green "📡 Receiving live data" indicator)
5. Tap **"Stop Tracking"** on iPhone
6. **Watch automatically stops** tracking too
7. View biosignal timeline charts in dream details

### Viewing Heart Rate Timeline
1. After stopping a sleep session, go to **main dashboard**
2. Tap on the **dream card**
3. Scroll to see:
   - **Heart Rate Timeline Chart**: Line graph with area fill
   - **HRV Chart**: Variability trends throughout night
   - **Statistics**: Average, Min, Max heart rate
   - **Interactive selection**: Tap chart to see specific time points

## 🔧 Technical Architecture

### WatchConnectivity Communication
**iPhone → Watch:**
- `startSleep`: Initiates tracking with session ID
- `stopSleep`: Ends tracking session
- `getCurrentMetrics`: Requests instant HR/HRV values

**Watch → iPhone:**
- `biosignalData`: HR/HRV samples every 5 minutes
- `sessionStarted`: Confirmation of tracking start
- `sessionStopped`: Confirmation of tracking end
- Context updates for background transfer

### Data Flow
```
Apple Watch (HealthKit)
    ↓ Real-time HR/HRV collection
WorkoutManager
    ↓ Every 5 minutes
WatchConnectivity
    ↓ Message/Context transfer
iPhone WatchConnectivityManager
    ↓ Parse and store
BiosignalDataPoint (SwiftData)
    ↓ Relationship
SleepData.biosignalTimeline
    ↓ Display
HeartRateChartView (SwiftUI Charts)
```

### Models

**BiosignalDataPoint:**
```swift
@Model
final class BiosignalDataPoint {
    var timestamp: Date      // When collected
    var heartRate: Double    // BPM from Watch
    var hrv: Double          // Calculated variability
    var movement: Double     // Future: accelerometer data
    var sleepSession: SleepData?  // Parent relationship
}
```

**SleepData (Updated):**
```swift
@Relationship(deleteRule: .cascade)
var biosignalTimeline: [BiosignalDataPoint] = []
```

### Chart Features
- **Line graph** with gradient area fill
- **5-minute intervals** on X-axis
- **Auto-scaling** Y-axis based on min/max
- **Statistics panel**: Avg/Min/Max with icons
- **Time formatting**: Shows elapsed time from sleep start
- **Empty state**: Graceful message when no Watch data
- **Separate HRV chart**: Independent visualization

## 📱 Requirements

### Hardware
- **iPhone** running iOS 17.0+
- **Apple Watch** running watchOS 10.0+
- **Paired devices** via Apple Watch app

### Permissions
- **HealthKit** permission on Apple Watch (requested automatically)
- **Motion & Fitness** tracking enabled in iOS Settings

### Network
- **No internet required** for Watch-iPhone sync
- Uses **Bluetooth** for direct communication
- **Background sync** via WatchConnectivity context updates

## 🎨 UI Elements

### iPhone Sleep Tracking View
```
┌─────────────────────────────┐
│  🌙 Tracking Your Dreams... │
│                             │
│   ⌚️ Watch Connected        │ ← Status indicator
│                             │
│      03:25:14               │ ← Elapsed time
│                             │
│   ❤️ 62 bpm   💓 45 ms      │ ← Live Watch data
│                             │
│ 📡 Receiving live data      │ ← Sync confirmation
│                             │
│   [Stop Tracking]           │
└─────────────────────────────┘
```

### Apple Watch App
```
┌─────────────────┐
│   🌙 DreamWeaver │
│   Tracking...    │
│                  │
│   ❤️ 62 BPM      │ ← Live HR
│   💓 45 ms       │ ← Live HRV
│                  │
│   03:25:14       │ ← Timer
│                  │
│ 📡 Syncing to    │
│    iPhone        │
│                  │
│   [Stop]         │
└─────────────────┘
```

### Heart Rate Chart (iPhone)
```
┌─────────────────────────────────────┐
│ ❤️ Heart Rate Timeline  20 samples  │
│                                     │
│ Heart Rate: 62 bpm  Time: 1h 25m   │ ← Selected point
│                                     │
│  80 ┼─╮                            │
│     │  ╰╮    ╭╮                    │
│  70 ┼   ╰─╮ ╭╯╰╮  ╭─╮             │
│     │     ╰─╯  ╰──╯ ╰╮            │
│  60 ┼                ╰───          │
│     │                              │
│  50 ┼                              │
│     └─────────────────────────────  │
│     0m    1h    2h    3h    4h     │
│                                     │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  │
│                                     │
│ 📊 Avg: 65 bpm  ⬇️ Min: 52 bpm    │
│ ⬆️ Max: 78 bpm                     │
└─────────────────────────────────────┘
```

## 🔐 Privacy & Security

### Data Storage
- **All biosignal data stored locally** on iPhone
- **SwiftData encryption** at rest
- **No cloud sync** by default
- **User controls** all data

### HealthKit Access
- **Watch only requests HR/HRV** permissions
- **No health data stored on Watch** permanently
- **Transferred immediately** to iPhone
- **HealthKit privacy** framework compliance

### WatchConnectivity
- **Direct Bluetooth** communication
- **No intermediary servers**
- **Encrypted by iOS/watchOS** automatically
- **Session-based** authentication

## 🐛 Troubleshooting

### Watch not connecting
**Solution:**
1. Ensure Watch and iPhone are paired in **Watch app**
2. Check **Bluetooth is enabled** on both devices
3. Keep devices **within 10 meters** during tracking
4. Restart **WatchConnectivity** by force-quitting apps

### No heart rate data showing
**Solution:**
1. Grant **HealthKit permissions** on Watch (Settings → Health → Data Access)
2. Ensure **Wrist Detection** enabled (Watch app → Passcode)
3. Check **Watch is worn properly** (snug but comfortable)
4. Start tracking from Watch first, then check iPhone

### Data not syncing
**Solution:**
1. Check **"📡 Receiving live data"** indicator on iPhone
2. Verify **Watch Connected** green badge shows
3. Wait 5 minutes for next **automatic sync**
4. If still fails, **stop and restart** tracking

### Charts show no data
**Solution:**
1. Ensure you **tracked with Apple Watch** (not iPhone-only simulation)
2. Check **biosignalTimeline has entries** (should show "X samples")
3. Verify tracking ran for **at least 5 minutes**
4. Data points saved **every 5 minutes**, so short sessions may have few samples

### Watch app won't start
**Solution:**
1. **Physical Watch required** - simulators don't support HealthKit fully
2. Install app from **Xcode to physical Watch** paired with Mac
3. Check **watchOS version** is 10.0+
4. Ensure **iPhone app installed first**

## 🚧 Known Limitations

### Simulator Constraints
- **Apple Watch simulators** don't fully support HealthKit
- **Heart rate collection** requires physical Apple Watch
- **WatchConnectivity** works in simulator but no real HR data
- **Testing requires paired physical devices**

### HealthKit Data
- **HRV calculation** is simplified (production should use proper R-R intervals)
- **Movement data** from accelerometer not yet implemented
- **Sleep stages** (REM/Deep) still estimated, not from Watch

### Battery Impact
- **Continuous HR tracking** uses more battery than normal
- **5-minute sync intervals** balance battery vs data resolution
- **Overnight tracking** (8 hours) typically uses 15-20% Watch battery
- **Recommended**: Charge Watch to 80%+ before sleep

## 🔮 Future Enhancements

### Planned Features
- **Real sleep stage detection** from Watch sensors
- **Accelerometer data** for movement tracking
- **Blood oxygen** monitoring (Watch Series 6+)
- **Respiratory rate** from motion sensors
- **Temperature sensing** (Watch Series 8+)
- **Export to Apple Health** app
- **Weekly/monthly trends** analysis
- **Smart alarms** based on sleep cycles
- **Share with partners** via iCloud

### AI Enhancements
- **Predict dream mood** from real-time HR patterns
- **Detect sleep disturbances** automatically
- **Personalized insights** based on your data
- **Sleep recommendations** powered by AI

## 📊 Data Examples

### Typical Sleep Session

**Duration**: 7h 45m  
**Data Points**: 93 samples (every 5 minutes)  
**Average Heart Rate**: 58 bpm  
**Min HR**: 48 bpm (deep sleep)  
**Max HR**: 72 bpm (REM sleep)  
**Average HRV**: 65 ms  
**HRV Range**: 42-88 ms

### Chart Interpretation
- **Low HR + High HRV** = Deep, restorative sleep
- **High HR + Low HRV** = Light sleep or REM
- **Spikes in HR** = Possible disturbances
- **Steady HR** = Stable, quality sleep

## 🆘 Support

### Getting Help
1. Check **"Watch Connected"** status on iPhone
2. Review **Console logs** for sync messages
3. Verify **HealthKit permissions** granted
4. Test with **short 5-minute session** first

### Debug Mode
Enable verbose logging by checking console for:
- `✅` Success messages (data sent/received)
- `📱` iPhone connectivity events
- `⌚️` Watch session activation
- `❌` Error messages with descriptions

## 🎉 Success Indicators

You know it's working when you see:
- ✅ **"⌚️ Watch Connected"** badge on iPhone
- ✅ **"📡 Receiving live data from Watch"** during tracking
- ✅ **Real heart rate values** updating live (not simulated 60-70 range)
- ✅ **Heart Rate Timeline chart** with data after session
- ✅ **Multiple data points** (one every 5 minutes)
- ✅ **HRV values** showing (not zero)

---

## Quick Start Checklist

- [ ] **Pair Apple Watch** with iPhone
- [ ] **Install DreamWeaver** on both devices
- [ ] **Grant HealthKit permission** on Watch
- [ ] **Open Watch app** and tap Start
- [ ] **Verify iPhone** shows "Watch Connected"
- [ ] **See live heart rate** updating on iPhone
- [ ] **Wait 5+ minutes** for first data sync
- [ ] **Stop tracking** from either device
- [ ] **View heart rate chart** in dream details
- [ ] **Celebrate** your first successful Watch-synced dream! 🎉

---

*Ready to track your dreams with real physiological data? Put on your Apple Watch and start dreaming!* 🌙⌚️
