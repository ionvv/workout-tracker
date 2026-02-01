# Supabase Database Setup

## Step 1: Run SQL Schema

1. Go to your Supabase project: https://supabase.com/dashboard/project/fpatywrdrltaeftjjyjj
2. Click **SQL Editor** in the left sidebar
3. Click **+ New Query**
4. Copy and paste the entire contents of `supabase-schema.sql`
5. Click **Run** (bottom right)

You should see: "Success. No rows returned"

## Step 2: Verify Tables Created

1. Click **Table Editor** in the left sidebar
2. You should see two new tables:
   - `programs`
   - `sessions`

## Step 3: Enable Email Confirmations (Optional)

By default, Supabase requires email confirmation for new signups.

**To disable email confirmation** (for faster testing):

1. Go to **Authentication** → **Settings** → **Email Auth**
2. Scroll to "Confirm email"
3. Toggle **OFF**
4. Save

**Or keep it enabled** (more secure):
- Users will receive a confirmation email
- They must click the link before they can sign in

## Step 4: Test the App

1. Deploy the updated app to Cloudflare Pages (auto-deploys on push)
2. Visit https://workout-tracker-963.pages.dev/
3. You'll see the new login page
4. Create an account with email + password
5. Import a program and start a workout
6. Sign out and sign in from another device
7. Your programs and sessions should appear!

## How Sync Works

- **Offline-first**: Data always saves to IndexedDB first (works offline)
- **Auto-sync**: When you sign in, data syncs from cloud
- **Cloud backup**: Programs and sessions auto-upload to Supabase
- **Multi-device**: Sign in on any device to see your data

## Troubleshooting

**"Failed to sync from cloud"**
- Check browser console for errors
- Verify SQL schema ran successfully
- Check Supabase project status

**"Sign in failed"**
- Verify email/password are correct
- Check if email confirmation is required (see Step 3)
- Check Supabase logs: Authentication → Logs

**Programs/sessions not syncing**
- Open browser dev tools → Console
- Look for "Sync to cloud failed" errors
- Verify you're signed in (check header on Programs page)

## Security

- All data is encrypted in transit (HTTPS)
- Row-level security enabled (users can only see their own data)
- API keys are public (safe to commit) - they only work with RLS policies
- Passwords are hashed by Supabase Auth (never stored in plain text)
