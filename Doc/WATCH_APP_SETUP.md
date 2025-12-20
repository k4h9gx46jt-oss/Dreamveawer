# Apple Watch Setup Guide for DreamWeaver ⌚

## What I've Created

I've added all the necessary code files for Apple Watch support! Here's what's ready:

### Watch App Files Created:
- ✅ `DreamWeaverWatchApp.swift` - Main Watch app
- ✅ `ContentView.swift` - Watch UI interface
- ✅ `WorkoutManager.swift` - Heart rate tracking & HealthKit
- ✅ `WatchConnectivityManager.swift` - iPhone ↔️ Watch communication
- ✅ `Info.plist` - HealthKit permissions

## Manual Steps to Add Watch Target in Xcode

Since the files are created, you now need to add the Watch App target to your Xcode project:

### Step 1: Add Watch App Target

1. **Open your project** in Xcode (`Dream Vewawer.xcodeproj`)

2. **In Xcode menu**, go to:
   ```
   File → New → Target...
   ```

3. In the template chooser:
   - Select **"watchOS"** tab at the top
   - Choose **"Watch App"**
   - Click **"Next"**

4. Configure the Watch App:
   - **Product Name**: `DreamWeaver Watch App`
   - **Team**: Select your Personal Team (jozsef.gazsik@erstegroup.com)
   - **Organization Identifier**: `GJSA` (or keep existing)
   - **Bundle Identifier**: Will auto-generate as `GJSA.Dream-Vewawer.watchkitapp`
   - **Language**: Swift
   - **Uncheck** "Include Notification Scene" (we don't need it yet)
   - Click **"Finish"**

5. When prompted **"Activate scheme?"**:
   - Click **"Activate"** (this will let you run on Watch)

### Step 2: Replace Template Files with Our Code

The template creates some default files. We need to replace them:

1. **Delete template files** (select and press Delete, choose "Move to Trash"):
   ```
   DreamWeaver Watch App/
   ├── DreamWeaver_Watch_AppApp.swift (delete)
   ├── ContentView.swift (delete)
   └── Assets.xcassets (keep this)
   ```

2. **Add our files to the target**:
   - In Xcode's **Project Navigator** (left sidebar)
   - Find the folder: `DreamWeaver Watch App/` (the one we created)
   - **Drag these files** from Finder into Xcode's `DreamWeaver Watch App` group:
     - `DreamWeaverWatchApp.swift`
     - `ContentView.swift`
     - `WorkoutManager.swift`
   
3. **Add Shared folder**:
   - In Project Navigator, right-click on project root
   - Select **"Add Files to Dream Vewawer..."**
   - Navigate to and select the `Shared/` folder
   - ✅ Check **both targets**: "Dream Vewawer" AND "DreamWeaver Watch App"
   - Click **"Add"**

### Step 3: Enable HealthKit Capability

1. Select your **Watch App target** in project settings
2. Click **"Signing & Capabilities"** tab
3. Click **"+ Capability"** button
4. Search for and add: **"HealthKit"**
5. HealthKit should now appear in the capabilities list

### Step 4: Add Background Modes

1. Still in **"Signing & Capabilities"**
2. Click **"+ Capability"** again
3. Add: **"Background Modes"**
4. Check the box: ☑️ **"Workout Processing"**

### Step 5: Update iPhone App for Watch Communication

Add WatchConnectivity to your iPhone app:

1. Open `Dream_VewawerApp.swift`
2. Import WatchConnectivity at the top:
   ```swift
   import WatchConnectivity
   ```
3. Add this inside the `Dream_VewawerApp` struct:
   ```swift
   @StateObject private var connectivityManager = WatchConnectivityManager.shared
   ```

---

## Alternative: Quick Setup Using Terminal

If you prefer command line, I can help generate the Xcode project modifications automatically. Let me know!

---

## Testing the Watch App

### Option 1: Simulator (Testing Only)
1. In Xcode, select **"DreamWeaver Watch App"** scheme
2. Choose **"Apple Watch Series 9 (45mm)"** or similar simulator
3. Press **⌘R** to run
4. The Watch simulator will launch
5. Test the interface (no real heart rate data)

### Option 2: Real Apple Watch (Recommended!)
1. **Pair your Apple Watch** with your iPhone
2. Connect **both iPhone and Mac** to the same WiFi
3. In Xcode, select **your Apple Watch** from device menu
4. Press **⌘R** to build and install
5. **On Watch**: Trust developer profile (similar to iPhone)
6. Launch DreamWeaver on Watch!

---

## What the Watch App Does

### Features:
- 🎯 **Start/Stop sleep tracking** from Watch
- ❤️ **Real-time heart rate monitoring** using HealthKit
- ⏱️ **Live elapsed time** display
- 🔄 **Automatic sync** to iPhone app
- 🔋 **Background tracking** overnight
- 📊 **Workout session** for continuous monitoring

### How It Works:
1. **Start tracking** on Watch before bed
2. Watch monitors heart rate continuously
3. Data streams to iPhone via WatchConnectivity
4. iPhone creates dream visualization with real biosignals
5. **Stop tracking** in the morning
6. View your dream on iPhone!

---

## Troubleshooting

### "Missing required capabilities"
- Make sure HealthKit capability is added to Watch target
- Check Background Modes → Workout Processing is enabled

### "Watch is not reachable"
- iPhone and Watch must be paired
- Both devices should be unlocked
- Bluetooth must be enabled

### Build errors about missing files
- Make sure all files are added to the correct target
- Check Target Membership in File Inspector (right sidebar)

---

## Next Steps After Setup

1. ✅ Add Watch target to Xcode
2. ✅ Replace template files with our code
3. ✅ Enable HealthKit & Background Modes
4. 🧪 Test on Watch simulator first
5. ⌚ Deploy to real Apple Watch
6. 🎨 Track real sleep and see beautiful dream visualizations!

---

## File Structure After Setup

```
Dream Vewawer/
├── Dream Vewawer/              # iPhone App
│   ├── Models/
│   ├── Views/
│   ├── Services/
│   └── ...
├── DreamWeaver Watch App/      # Watch App
│   ├── DreamWeaverWatchApp.swift
│   ├── ContentView.swift
│   ├── WorkoutManager.swift
│   ├── Info.plist
│   └── Assets.xcassets/
├── Shared/                     # Shared between iPhone & Watch
│   └── WatchConnectivityManager.swift
└── Dream Vewawer.xcodeproj
```

---

**Ready to track real dreams with your Apple Watch!** 🌙⌚✨

Need help with any step? Let me know!
