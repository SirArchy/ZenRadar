# Google Sign-in Setup Guide

## Step 1: Get your Web Client ID

1. Go to the [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project (zenradar-acb85)
3. Go to **APIs & Services** > **Credentials**
4. Look for your **Web client** (OAuth 2.0 Client IDs)
5. Copy the **Client ID** (it should end with `.apps.googleusercontent.com`)

## Step 2: Update Configuration

1. Open `web/index.html`
2. Replace `YOUR_WEB_CLIENT_ID` with your actual web client ID:
   ```html
   <meta name="google-signin-client_id" content="989787576521-YOUR_ACTUAL_CLIENT_ID.apps.googleusercontent.com">
   ```

## Step 3: Configure Authorized Domains

In your Google Cloud Console:
1. Go to **APIs & Services** > **Credentials**
2. Click on your Web client
3. Add these to **Authorized JavaScript origins**:
   - `http://localhost` (for development)
   - `http://localhost:port` (replace port with your Flutter web port)
   - Your production domain when you deploy

## Step 4: Enable Required APIs

Make sure these APIs are enabled in your Google Cloud Console:
1. Go to **APIs & Services** > **Library**
2. Search for and enable:
   - Google+ API
   - People API
   - Identity and Access Management (IAM) API

## Current Configuration

Your Firebase project ID: `zenradar-acb85`
Your messaging sender ID: `989787576521`

## Troubleshooting

If you get "invalid_client" error:
1. Double-check the client ID in `web/index.html`
2. Ensure the domain is authorized in Google Cloud Console
3. Clear browser cache and cookies
4. Make sure the Google+ API is enabled

## Testing

1. Run `flutter run -d chrome`
2. Try Google Sign-in
3. Check browser console for any errors

---

## Android Error Code 10 Fix

**Error**: `PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 10: , null, null)`

**Cause**: Your app's SHA-1 fingerprint is not registered in Firebase Console.

### Solution:

1. **Get SHA-1 fingerprint**:
   ```bash
   cd android
   .\gradlew signingReport
   ```
   Copy the **SHA1** value from the debug section.

2. **Add to Firebase Console**:
   - Go to Firebase Console > Project Settings
   - Select Android app (`com.zenradar.zenradar`)
   - Add SHA-1 under "SHA certificate fingerprints"
   - Download updated `google-services.json`

3. **Clean rebuild**:
   ```bash
   flutter clean && flutter pub get
   ```
