# Watch Target Capability Configuration

**Scope:** the capabilities and Info.plist keys the watch target requires. For
building and running see [WATCH_SETUP.md](WATCH_SETUP.md).

> This document previously walked through creating the watchOS target by hand and
> referenced a project named `Dream Vewawer`. **The target already exists** in
> `Ihpone/DreamWeaver/DreamWeaver.xcodeproj` and that project name is obsolete.
> The manual creation steps have been removed. A personal email address was also
> removed from this file.

---

## 1. Existing targets

| Target | Bundle ID | Sources |
| --- | --- | --- |
| `DreamWeaver` | `GJDRW.DreamWeaver` | `Ihpone/` |
| `DreamWeaver WatchKit App` | `GJDRW.DreamWeaver.watchkitapp` | `Iwatch/` |
| `DreamWeaver WatchKit Extension` | `GJDRW.DreamWeaver.watchkitapp.watchkitextension` | `Iwatch/` |

`Shared/REMClassifier.swift` is a member of **both** platform targets. If you add
files there, verify Target Membership in the File Inspector for both.

The watch extension uses a checked-in Info.plist at
`Iwatch/WatchExtension-Info.plist` (`GENERATE_INFOPLIST_FILE = NO`). The other
targets use generated plists driven by `INFOPLIST_KEY_*` build settings.

---

## 2. Required capabilities

### 2.1 HealthKit — ⚠️ currently missing

**No `.entitlements` file exists for any target.** Without it,
`HKHealthStore.requestAuthorization` fails on real hardware and every biosignal
read returns nothing. The simulator hides this.

Add to both the iOS app and the watch app:

1. Target → **Signing & Capabilities** → **+ Capability** → **HealthKit**
2. Xcode creates a `.entitlements` file containing:

```xml
<key>com.apple.developer.healthkit</key>
<true/>
<key>com.apple.developer.healthkit.access</key>
<array/>
```

If sessions are later written back to the Health app, the *share* permission is
needed in addition to *read*.

### 2.2 Background Modes — ⚠️ currently missing

Watch target → **+ Capability** → **Background Modes** → tick **Workout
Processing**. Without it the system terminates overnight sessions.

This adds to the extension Info.plist:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>workout-processing</string>
</array>
```

---

## 3. Usage description strings

### Watch extension — ✅ present

`Iwatch/WatchExtension-Info.plist` already declares
`NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription`.

### iOS app — ⚠️ missing

The iOS target declares **neither**. Calling HealthKit without a usage string is
an immediate crash and a guaranteed App Store rejection.

Add these build settings to the iOS target:

- `INFOPLIST_KEY_NSHealthShareUsageDescription`
- `INFOPLIST_KEY_NSHealthUpdateUsageDescription`

Be specific about *why* the data is needed — vague strings are rejected under
Guideline 5.1.1(i).

---

## 4. Privacy manifest — ⚠️ missing

`PrivacyInfo.xcprivacy` has been mandatory since 1 May 2024 and App Store Connect
rejects uploads without it. Add one per target. It must declare Health & Fitness
data collection and a required-reason entry for `UserDefaults` (reason code
`CA92.1`, used by `WorkoutManager` for session restore).

Full detail: [APP_STORE_CHECKLIST.md](APP_STORE_CHECKLIST.md) §0.3.

---

## 5. Verification

```bash
./run-tests.sh          # builds both platforms and runs the unit suites
```

Then on a **physical** watch:

1. Launch the watch app and tap Start.
2. Confirm the HealthKit permission sheet appears.
3. Confirm heart rate becomes non-zero within ~30 seconds.
4. Confirm the iPhone reflects the active session.

If step 2 does not happen, the entitlement from §2.1 is missing.

---

## 6. Configuration checklist

- [ ] HealthKit capability on the iOS target
- [ ] HealthKit capability on the watch target
- [ ] Background Modes → Workout Processing on the watch target
- [ ] `NSHealthShareUsageDescription` on the iOS target
- [ ] `NSHealthUpdateUsageDescription` on the iOS target
- [ ] `PrivacyInfo.xcprivacy` on both targets
- [ ] `Shared/` files are members of both platform targets
- [ ] Both targets signed with the same team
- [ ] Bundle IDs converted to reverse-DNS before first submission
