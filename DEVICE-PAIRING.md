# Device Pairing System

## Overview

The device pairing system allows Apple Watch (and future devices) to authenticate via a **temporary 6-digit code** instead of typing email/password on the device.

**Flow:**
1. Watch app generates a unique 6-digit code (valid for 3 minutes)
2. User enters code on web app (after logging in)
3. Watch polls backend and auto-logs in when authorized

---

## Database Setup

Run these SQL files in your Supabase SQL Editor (in order):

### 1. Create Table

```bash
supabase-device-pairing.sql
```

Creates the `device_auth_codes` table with RLS policies.

### 2. Create Functions

```bash
supabase-device-pairing-functions.sql
```

Creates PostgreSQL RPC functions:
- `request_pairing_code(device_id)` - Generate code
- `check_device_authorization(device_id)` - Poll for auth
- `authorize_pairing_code(code, user_id)` - Authorize code

---

## Deployment Steps

### 1. Deploy Database Changes

**In Supabase Dashboard:**

1. Go to **SQL Editor**
2. **Run first:** Copy/paste `supabase-device-pairing.sql` → Execute
3. **Run second:** Copy/paste `supabase-device-pairing-functions.sql` → Execute
4. Verify table exists: **Table Editor** → Should see `device_auth_codes`

### 2. Deploy Web App

```bash
# Commit and push changes
git add -A
git commit -m "feat: add device pairing system for Apple Watch"
git push

# Deploy to Vercel/Netlify/etc (your usual deployment)
```

**New pages added:**
- `/pair-device` - Device pairing page (enter 6-digit code)

### 3. Deploy Apple Watch App

**In Xcode:**

1. Open `VRN Workouts.xcodeproj`
2. Select **VRN Workouts Watch App** scheme
3. Select destination: **Apple Watch Series 11** (simulator) or your physical watch
4. Product → Run (⌘R)

**New files added:**
- `DevicePairingView.swift` - Pairing UI
- `DevicePairingViewModel.swift` - Pairing logic

---

## Testing

### Test Pairing Flow (Simulator)

1. **Launch Watch App** in simulator
   - Should show 6-digit code (e.g., "123456")
   - Countdown timer shows 3:00 → 0:00

2. **Open Web App** in browser
   - Go to login page → Click **"⌚ Pair Apple Watch"**
   - OR go directly to `/pair-device`
   - Enter the 6-digit code from watch
   - Click **"Pair Device"**

3. **Watch Auto-Logs In**
   - Watch polls every 3 seconds
   - Once authorized, shows success haptic + navigates to Programs

### Test on Physical Watch

**Requirements:**
- Apple Watch paired with your iPhone
- Watch updated to latest watchOS
- Signed in to Apple Developer account in Xcode

**Steps:**
1. Connect iPhone to Mac (with watch paired)
2. In Xcode: Select **your physical watch** as destination
3. Build & Run
4. Accept provisioning profile if prompted
5. Test pairing flow as above

---

## API Endpoints

### Request Pairing Code
```javascript
POST /rest/v1/rpc/request_pairing_code
Body: { "device_id": "uuid-from-watch" }
Response: { "code": "123456", "expires_at": "2024-..." }
```

### Check Authorization (Polling)
```javascript
POST /rest/v1/rpc/check_device_authorization
Body: { "device_id": "uuid-from-watch" }
Response: { "authorized": true, "user_id": "uuid", "authorized_at": "..." }
```

### Authorize Code
```javascript
POST /rest/v1/rpc/authorize_pairing_code
Body: { "p_code": "123456", "p_user_id": "uuid" }
Response: { "success": true, "message": "Device paired successfully" }
```

---

## Security Notes

- **Codes expire after 3 minutes** (prevent brute force)
- **One-time use** (authorized codes can't be reused)
- **RLS policies** ensure users can only authorize their own codes
- **Device ID** stored in watch UserDefaults (persists across restarts)

---

## Future Improvements

1. **Session Tokens:** Generate proper Supabase session token for watch instead of just storing user ID
2. **Push Notifications:** Notify web user when a watch requests pairing
3. **Device Management:** Web page to view/revoke paired devices
4. **Refresh Tokens:** Auto-renew watch sessions without re-pairing
5. **Multi-Device Support:** Same flow for Android Wear, Fitbit, etc.

---

## Troubleshooting

### Watch shows "Failed to generate code"
- Check internet connection
- Verify Supabase URL/key in `Config.swift`
- Check database functions are deployed

### Web app shows "Invalid or expired code"
- Code must be entered within 3 minutes
- Code can only be used once
- User must be logged in to web app

### Watch doesn't auto-login after pairing
- Check watch is polling (should see "Waiting for authorization...")
- Verify `authorize_pairing_code` function executed successfully
- Check `AuthService.checkDeviceAuthorization()` is called

---

## Files Modified/Added

### Database
- `supabase-device-pairing.sql` - Table schema
- `supabase-device-pairing-functions.sql` - RPC functions

### Web App
- `src/api/devicePairing.js` - API functions
- `src/views/PairDevice.vue` - Pairing UI
- `src/router/index.js` - Added `/pair-device` route
- `src/views/Login.vue` - Added "Pair Watch" link

### Apple Watch
- `Views/DevicePairingView.swift` - Pairing UI
- `ViewModels/DevicePairingViewModel.swift` - Pairing logic
- `Services/AuthService.swift` - Device auth support
- `App/WorkoutTrackerApp.swift` - Show pairing on launch

---

**Status:** ✅ Ready for deployment!
