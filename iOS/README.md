# Workout Tracker - Apple Watch App

Native watchOS app for logging workouts directly from your Apple Watch.

## Features

- 🔐 Sign in with email/password (Supabase Auth)
- ☁️ Syncs with web app via Supabase
- ⌚ Digital Crown for weight adjustment
- 👆 Tap to increment reps
- 📳 Haptic feedback on set completion
- 🏋️ Works standalone (no iPhone needed)

## Requirements

- Xcode 15.0+
- watchOS 10.0+
- Apple Developer Account
- Apple Watch for testing

## Setup

### 1. Open in Xcode

```bash
cd workout-tracker-watch
open WorkoutTracker.xcodeproj
```

### 2. Configure Supabase

The Supabase credentials are already set in `Config.swift`:
- URL: https://fpatywrdrltaeftjjyjj.supabase.co
- Anon Key: (already configured)

### 3. Add Your Team

1. Select the project in Xcode
2. Go to "Signing & Capabilities"
3. Select your Apple Developer team
4. Xcode will automatically create App IDs

### 4. Install Dependencies

This project uses Swift Package Manager. Dependencies will auto-install:
- Supabase Swift SDK

### 5. Build & Run

1. Select your Apple Watch as the destination
2. Click Run (Cmd+R)
3. App installs on your Watch

## Project Structure

```
WorkoutTracker/
├── App/
│   ├── WorkoutTrackerApp.swift      # App entry point
│   └── Config.swift                 # Supabase config
├── Models/
│   ├── Program.swift                # Program data model
│   ├── Session.swift                # Session data model
│   └── User.swift                   # User auth model
├── Services/
│   ├── AuthService.swift            # Authentication
│   ├── ProgramService.swift         # Program sync
│   └── SessionService.swift         # Session sync
├── Views/
│   ├── LoginView.swift              # Sign in screen
│   ├── ProgramsView.swift           # Program list
│   ├── WorkoutView.swift            # Active workout
│   ├── SetLoggerView.swift          # Log sets
│   └── SummaryView.swift            # Workout summary
└── ViewModels/
    ├── AuthViewModel.swift          # Auth state
    ├── ProgramsViewModel.swift      # Programs state
    └── WorkoutViewModel.swift       # Workout state
```

## Usage

### First Launch

1. **Sign In** - Use same email/password as web app
2. **Programs Load** - Automatically syncs from cloud
3. **Start Workout** - Select program → Select day
4. **Log Sets** - Use Digital Crown for weight, tap for reps
5. **Finish** - Session syncs to cloud automatically

### Digital Crown Controls

- **Weight Field**: Rotate crown to adjust weight (2.5kg increments)
- **Reps Field**: Tap +/- or use crown for fine control

### Haptic Feedback

- Light tap when logging a set
- Success notification when workout completes
- Error notification on sync failures

## Troubleshooting

### "Build Failed"

- Make sure you selected a watchOS target (not iOS)
- Check Xcode is 15.0+
- Verify watchOS deployment target is 10.0+

### "No paired watch"

- Open Watch app on iPhone
- Ensure watch is paired and unlocked
- Try selecting a specific watch in Xcode destinations

### "Supabase connection failed"

- Check internet connection
- Verify credentials in `Config.swift`
- Check Supabase project is active

### "Session not syncing"

- Ensure you're signed in
- Check watch has internet (WiFi or paired iPhone)
- Verify Row Level Security policies in Supabase

## Development

### Running Locally

The Watch Simulator works but has limitations:
- Digital Crown simulation is imprecise
- Haptics don't work in simulator
- Network requests may be slower

**Recommended:** Test on real Apple Watch for best experience.

### Making Changes

1. Edit SwiftUI views in `Views/` folder
2. Update state in `ViewModels/`
3. Modify services in `Services/` for API changes
4. Build and run on Watch

## Deployment

### TestFlight (Beta Testing)

1. Archive the app (Product → Archive)
2. Upload to App Store Connect
3. Add testers via TestFlight
4. Testers install via TestFlight app on iPhone

### App Store

1. Create App Store listing in App Store Connect
2. Upload screenshots (Apple Watch screenshots)
3. Submit for review
4. Wait for approval (~1-3 days)

## Notes

- Sessions sync after workout completion (not real-time during sets)
- Programs sync on app launch and periodically
- Works offline - syncs when connection available
- Uses same database as web app (shared workouts)

## Support

Issues? Check:
- Xcode console for error messages
- Supabase logs for sync failures
- Watch Settings → General → About (for Watch OS version)
