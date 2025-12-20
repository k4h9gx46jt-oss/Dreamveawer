# Apple Watch Integration Roadmap ⌚

## Overview
This document outlines the plan to extend DreamWeaver to Apple Watch for real biosignal tracking during sleep.

## Phase 1: HealthKit Permissions (Week 1)

### Tasks
1. **Update Info.plist**
   ```xml
   <key>NSHealthShareUsageDescription</key>
   <string>DreamWeaver needs access to your heart rate and sleep data to create personalized dream visualizations.</string>
   
   <key>NSHealthUpdateUsageDescription</key>
   <string>DreamWeaver will store sleep sessions in HealthKit.</string>
   ```

2. **Update Capabilities**
   - Enable HealthKit in target capabilities
   - Add Background Modes: Background fetch, Remote notifications

3. **Request Permissions**
   - Integrate `HealthKitManager` into `SleepTrackingView`
   - Request authorization on first launch
   - Show permission status in settings

## Phase 2: Real-Time Data Collection (Week 2-3)

### iPhone App Updates

```swift
// Update SleepTrackingView.swift
class SleepTrackingViewModel: ObservableObject {
    @Published var healthKitManager = HealthKitManager()
    @Published var isTracking = false
    @Published var currentHeartRate: Double = 0
    @Published var heartRateHistory: [Double] = []
    
    func startRealTracking() {
        // Start continuous heart rate monitoring
        healthKitManager.startHeartRateStreaming { rate in
            DispatchQueue.main.async {
                self.currentHeartRate = rate
                self.heartRateHistory.append(rate)
            }
        }
    }
}
```

### Apple Watch App Creation

1. **Add watchOS Target**
   - File > New > Target > watchOS > Watch App
   - Name: "DreamWeaver Watch"

2. **Watch App Structure**
   ```
   DreamWeaver Watch/
     ContentView.swift      - Main interface
     SleepMonitorView.swift - Bedside mode
     WorkoutSession.swift   - Background tracking
   ```

3. **Watch ContentView**
   ```swift
   import SwiftUI
   import HealthKit
   import WatchKit
   
   struct ContentView: View {
       @State private var isTracking = false
       @State private var heartRate: Double = 0
       
       var body: some View {
           VStack {
               Text("DreamWeaver")
                   .font(.headline)
               
               if isTracking {
                   VStack {
                       Image(systemName: "heart.fill")
                           .foregroundColor(.red)
                       Text("\(Int(heartRate)) BPM")
                           .font(.title)
                   }
               }
               
               Button(isTracking ? "Stop" : "Start Sleep") {
                   toggleTracking()
               }
           }
       }
   }
   ```

## Phase 3: Background Processing (Week 4)

### Enable Background Tracking

1. **Workout Session**
   ```swift
   import HealthKit
   
   class SleepWorkoutManager: NSObject, ObservableObject {
       let healthStore = HKHealthStore()
       var session: HKWorkoutSession?
       var builder: HKLiveWorkoutBuilder?
       
       func startWorkout() {
           let configuration = HKWorkoutConfiguration()
           configuration.activityType = .other
           configuration.locationType = .indoor
           
           do {
               session = try HKWorkoutSession(
                   healthStore: healthStore,
                   configuration: configuration
               )
               builder = session?.associatedWorkoutBuilder()
               
               session?.startActivity(with: Date())
               builder?.beginCollection(withStart: Date()) { _, _ in }
           } catch {
               print("Failed to start workout: \(error)")
           }
       }
   }
   ```

2. **Background Delivery**
   - Enable background delivery for heart rate
   - Store data in shared container
   - Sync to iPhone app

## Phase 4: Watch-iPhone Communication (Week 5)

### WatchConnectivity Setup

```swift
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()
    
    @Published var sleepData: [String: Any] = [:]
    
    override init() {
        super.init()
        
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }
    
    func sendSleepData(_ data: [String: Any]) {
        guard WCSession.default.isReachable else { return }
        
        WCSession.default.sendMessage(data) { response in
            print("Data sent successfully")
        } errorHandler: { error in
            print("Error sending data: \(error)")
        }
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    // Implement required methods
}
```

## Phase 5: Bedside Mode (Week 6)

### Watch Features

1. **Always-On Display**
   - Show minimal UI during sleep
   - Display current time
   - Heart rate indicator
   - Silent animations

2. **Sleep Staging**
   - Detect REM vs Deep sleep
   - Use motion sensors + heart rate
   - Simple ML model for classification

3. **Smart Wake**
   - Gentle haptic alarm
   - Wake during light sleep phase
   - Morning summary on Watch

## Phase 6: Advanced Features (Week 7-8)

### Motion Tracking
```swift
import CoreMotion

class MotionManager: ObservableObject {
    let motionManager = CMMotionManager()
    
    @Published var movementIntensity: Double = 0
    
    func startTracking() {
        guard motionManager.isAccelerometerAvailable else { return }
        
        motionManager.accelerometerUpdateInterval = 1.0
        motionManager.startAccelerometerUpdates(to: .main) { data, error in
            guard let data = data else { return }
            
            let x = data.acceleration.x
            let y = data.acceleration.y
            let z = data.acceleration.z
            
            let magnitude = sqrt(x*x + y*y + z*z)
            self.movementIntensity = magnitude
        }
    }
}
```

### Ambient Sound Analysis (iPhone)
```swift
import AVFoundation

class AudioMonitor: ObservableObject {
    let audioEngine = AVAudioEngine()
    
    @Published var noiseLevel: Double = 0
    
    func startMonitoring() {
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            // Analyze audio buffer for volume
            let level = self.calculateLevel(buffer)
            DispatchQueue.main.async {
                self.noiseLevel = level
            }
        }
        
        audioEngine.prepare()
        try? audioEngine.start()
    }
}
```

## Testing Strategy

### Unit Tests
- HealthKit data parsing
- Dream mood algorithm
- Color generation logic

### Integration Tests
- Watch-iPhone communication
- Background data collection
- Data persistence

### User Testing
- Sleep with Watch for multiple nights
- Verify accuracy of biosignals
- Test battery life impact

## Privacy & Battery Considerations

### Privacy
- All data stored locally
- No cloud sync (unless user opts in)
- Clear permission requests
- Data deletion options

### Battery Optimization
- Sample heart rate every 30s (not continuous)
- Reduce screen brightness on Watch
- Stop tracking automatically after 12 hours
- Efficient data processing

## Success Metrics

- ✅ Accurate heart rate tracking (±5 bpm)
- ✅ Battery usage < 15% overnight
- ✅ Reliable Watch-iPhone sync
- ✅ User satisfaction with visualizations
- ✅ No crashes during overnight tracking

## Required Resources

### Hardware
- Apple Watch Series 4 or later (heart rate sensor)
- iPhone 12 or later
- Both devices charged to 100% for testing

### Software
- Xcode 15+
- watchOS 10+
- iOS 17+

### Documentation
- Apple HealthKit Programming Guide
- watchOS App Programming Guide
- WatchConnectivity Framework Reference

## Timeline Summary

| Week | Focus | Deliverable |
|------|-------|-------------|
| 1 | HealthKit Setup | Permissions working |
| 2-3 | Watch App | Basic tracking |
| 4 | Background Mode | All-night tracking |
| 5 | Communication | Data sync |
| 6 | Bedside Mode | Polished Watch UI |
| 7-8 | Polish | Advanced features |

## Next Immediate Steps

1. ✅ Complete iPhone app (DONE!)
2. → Add HealthKit permissions
3. → Test with simulated Watch data
4. → Create Watch app target
5. → Implement basic heart rate tracking

---

**Ready to bring real biosignals to your dreams!** 🌙⌚
