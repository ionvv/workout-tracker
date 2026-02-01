# Creating the Xcode Project

## Step 1: Create New watchOS Project

1. Open Xcode
2. File → New → Project
3. Select **watchOS** tab → **App**
4. Click **Next**

**Configure:**
- Product Name: `WorkoutTracker`
- Team: (Select your Apple Developer team)
- Organization Identifier: `com.yourname.workouttracker` (use your own)
- Interface: **SwiftUI**
- Language: **Swift**
- Click **Next** and save

## Step 2: Add Swift Package Dependencies

1. In Xcode, click on project name in navigator
2. Select **WorkoutTracker** target
3. Click **Package Dependencies** tab
4. Click **+** button
5. Enter package URL: `https://github.com/supabase-community/supabase-swift`
6. Click **Add Package**
7. Select **Supabase** library
8. Click **Add Package**

## Step 3: Replace Generated Files

The project created some default files. Replace them with our custom files:

### Delete These Default Files:
- `ContentView.swift` (we have our own views)
- Any default test files

### Add Our Files:

**From this repo, add all files in:**
- `WorkoutTracker/App/` → Add to Xcode project
- `WorkoutTracker/Models/` → Add to Xcode project  
- `WorkoutTracker/Services/` → Add to Xcode project
- `WorkoutTracker/Views/` → Add to Xcode project
- `WorkoutTracker/ViewModels/` → Add to Xcode project

**How to add files in Xcode:**
1. Right-click on `WorkoutTracker` folder in navigator
2. **Add Files to "WorkoutTracker"...**
3. Select our Swift files
4. Ensure **"Copy items if needed"** is checked
5. Click **Add**

## Step 4: Update App Entry Point

Replace `WorkoutTrackerApp.swift` content with our version from `App/WorkoutTrackerApp.swift`

## Step 5: Configure Info.plist

Add these keys to your `Info.plist`:

**Privacy - Network Usage Description:**
```
This app needs network access to sync your workout data with the cloud.
```

## Step 6: Build & Run

1. Select your Apple Watch as the run destination
2. Click Run (⌘R)
3. App installs on your Watch
4. Sign in with same credentials as web app

## Troubleshooting

**"Cannot find 'Supabase' in scope"**
- Verify Swift package was added correctly
- Product → Clean Build Folder
- Rebuild

**"Signing requires a development team"**
- Select your Apple Developer team in Signing & Capabilities
- Xcode will create App IDs automatically

**"No such module 'Supabase'"**
- Check Package Dependencies tab shows Supabase
- Try removing and re-adding the package

**Build succeeds but app doesn't appear on Watch**
- Check Watch is unlocked
- Ensure Watch and iPhone are paired
- Try restarting both devices
