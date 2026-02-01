# Quick Start Guide - 5 Minutes to Build

## Prerequisites

✅ Mac with Xcode 15.0+
✅ Apple Developer Account
✅ Apple Watch (for testing)

## Setup Steps

### 1. Create Xcode Project (2 minutes)

1. Open Xcode
2. File → New → Project
3. **watchOS** tab → **App** → Next
4. Configure:
   - Product Name: `WorkoutTracker`
   - Team: (Your Apple Developer team)
   - Organization Identifier: `com.yourname.workouttracker`
   - Interface: **SwiftUI**
   - Language: **Swift**
5. Save anywhere on your Mac

### 2. Add Supabase Package (1 minute)

1. In Xcode project navigator, click `WorkoutTracker` (top)
2. Select **WorkoutTracker** target
3. Go to **Package Dependencies** tab
4. Click **+** button
5. Enter: `https://github.com/supabase-community/supabase-swift`
6. Click **Add Package**
7. Select **Supabase** library → **Add Package**

### 3. Add Source Files (2 minutes)

1. **Delete** these generated files in Xcode:
   - `ContentView.swift`
   - Any test files

2. **Add our files:**
   - Drag the entire `WorkoutTracker` folder from this repo into Xcode
   - Ensure "Copy items if needed" is **checked**
   - Click **Add**

### 4. Configure Privacy (30 seconds)

1. Open `Info.plist` in Xcode
2. Add new row:
   - Key: `NSLocalNetworkUsageDescription`
   - Value: `This app needs network access to sync your workout data`

### 5. Build & Run! (30 seconds)

1. Select your Apple Watch in the destination dropdown
2. Click Run (⌘R)
3. App installs on your Watch!

## First Use

1. Open app on Watch
2. Sign in (same email/password as web app)
3. Programs sync from cloud
4. Select program → Select day → Start workout!

## Digital Crown Usage

- **In Set Logger:**
  - Focus on Weight → Rotate crown to adjust
  - Focus on Reps → Rotate crown to adjust
  - Tap +/− buttons for quick changes

## Troubleshooting

**Build fails with "Cannot find 'Supabase'"**
→ Verify package was added correctly (Step 2)

**"No paired Apple Watch"**
→ Open Watch app on iPhone, ensure watch is paired

**"Signing requires development team"**
→ Select your team in Signing & Capabilities

**App installs but crashes**
→ Check Xcode console for error messages
→ Verify Supabase credentials in `Config.swift`

## Done!

You now have a fully functional Apple Watch workout tracker!

**Test it:**
- Log a workout on Watch
- Open web app → Data syncs! ✨
- Log on web → Open Watch → Data syncs! ✨

---

Questions? Check the full README.md for detailed docs.
