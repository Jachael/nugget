# Nugget App Authentication Testing Guide

## Overview
This guide provides comprehensive instructions for testing Apple Sign In and Google Sign In authentication in the Nugget app, both during development and before deploying to TestFlight.

## Current Authentication Setup

### Backend
- **Apple Sign In**: ✅ Configured with proper token verification
- **Google Sign In**: ✅ Handler created (requires Google Cloud configuration)
- **Mock Authentication**: ✅ Available for testing in simulator
- **JWT Token Management**: ✅ Implemented

### iOS App
- **App ID**: `erg.NuggetApp`
- **Sign in with Apple**: Enabled in Apple Developer Account
- **Authentication UI**: Liquid glass design with both Apple and Google buttons

## Testing Apple Sign In

### Prerequisites
1. **Real iPhone Device** (Apple Sign In doesn't work in simulator)
2. **Apple Developer Account** with Sign in with Apple capability enabled
3. **Xcode with your development certificate configured**

### Step 1: Build for Real Device
```bash
# Connect your iPhone to your Mac
# Open Xcode
cd /Users/jason/nugget/ios/NuggetApp
open NuggetApp.xcodeproj

# In Xcode:
# 1. Select your iPhone from the device list (not simulator)
# 2. Ensure "Automatically manage signing" is checked in Signing & Capabilities
# 3. Select your Development Team
# 4. Build and run (Cmd+R)
```

### Step 2: Test Apple Sign In Flow

#### First-Time User (Sign Up)
1. Launch the app on your iPhone
2. Tap "Sign in with Apple"
3. Use Face ID/Touch ID to authenticate
4. Choose to share or hide your email
5. Verify:
   - User is created in backend
   - Tutorial screens appear for new users
   - User lands on home screen
   - Streak shows as 1

#### Returning User (Sign In)
1. Sign out from Settings
2. Tap "Sign in with Apple" again
3. Authenticate with Face ID/Touch ID
4. Verify:
   - No email prompt (Apple remembers)
   - User data is preserved
   - Streak is maintained
   - No tutorial screens

### Step 3: Verify Backend Data
```bash
# Check if user was created in DynamoDB
aws dynamodb scan \
  --table-name nugget-users-prod \
  --filter-expression "begins_with(userId, :prefix)" \
  --expression-attribute-values '{":prefix":{"S":"usr_"}}' \
  --region eu-west-1

# Check authentication logs
aws logs tail /aws/lambda/nugget-prod-authApple \
  --follow \
  --region eu-west-1
```

## Testing Google Sign In

### Prerequisites
1. Google Cloud Project with OAuth 2.0 credentials
2. Google Sign-In SDK configuration

### Setup Google Cloud Console
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project or select existing
3. Enable Google Sign-In API:
   - Navigate to "APIs & Services" > "Library"
   - Search for "Google Sign-In API"
   - Click Enable

4. Create OAuth 2.0 Credentials:
   - Go to "APIs & Services" > "Credentials"
   - Click "Create Credentials" > "OAuth client ID"
   - Application type: iOS
   - Bundle ID: `erg.NuggetApp`
   - Copy the Client ID

5. Set Environment Variable:
```bash
# Add to your deployment environment
export GOOGLE_CLIENT_ID="your-google-client-id.apps.googleusercontent.com"
```

### iOS Google Sign In Implementation
The app UI is ready but needs Google Sign-In SDK integration:

```swift
// TODO: Add to LoginView.swift
private func signInWithGoogle() {
    // 1. Install GoogleSignIn SDK via Swift Package Manager
    // 2. Configure with your Client ID
    // 3. Present Google Sign In
    // 4. Send ID token to backend /v1/auth/google
}
```

## Testing Mock Authentication (Development)

### In Simulator
1. Launch app in simulator
2. Look for "Sign in with Test Account (Debug)" button
3. Tap to create mock user
4. Verify authentication works

### Via API
```bash
# Test mock authentication endpoint
curl -X POST https://nugget-api.jasonhome.workers.dev/v1/auth/mock \
  -H "Content-Type: application/json" \
  -H "X-Test-Auth: nugget-test-2024" \
  -d '{"mockUser": "test_user_123"}'
```

## Testing Checklist

### Pre-TestFlight Checklist

#### Authentication Flow
- [ ] Apple Sign In creates new user successfully
- [ ] Apple Sign In logs in existing user
- [ ] User data persists between sessions
- [ ] Token is stored securely in Keychain
- [ ] Token refresh works (if implemented)
- [ ] Sign out clears all credentials

#### User Experience
- [ ] Tutorial shows for new users only
- [ ] Onboarding flow completes properly
- [ ] Streak tracking works correctly
- [ ] Settings are saved and retrieved
- [ ] Error messages display appropriately

#### Backend Verification
- [ ] Users table has correct data structure
- [ ] Apple sub ID is stored correctly
- [ ] JWT tokens are valid and expire properly
- [ ] API endpoints require authentication
- [ ] Unauthorized requests return 401

#### Security
- [ ] No sensitive data in logs
- [ ] Tokens are not exposed in UI
- [ ] HTTPS only for API calls
- [ ] Keychain access is secure

### TestFlight Preparation

1. **Archive and Upload**:
```bash
# In Xcode:
# 1. Select "Any iOS Device" as destination
# 2. Product > Archive
# 3. Distribute App > TestFlight & App Store
# 4. Upload to App Store Connect
```

2. **Configure in App Store Connect**:
- Add TestFlight test information
- Enable Sign in with Apple
- Add test users
- Submit for TestFlight review

3. **Monitor**:
```bash
# Watch backend logs during testing
aws logs tail /aws/lambda/nugget-prod-authApple --follow --region eu-west-1
aws logs tail /aws/lambda/nugget-prod-authGoogle --follow --region eu-west-1
```

## Common Issues and Solutions

### Issue: Apple Sign In not working on device
**Solution**: Ensure:
- Sign in with Apple capability is enabled in Xcode
- Entitlements file includes Sign in with Apple
- App ID in Apple Developer matches Bundle ID

### Issue: "Invalid Apple ID token" error
**Solution**:
- Token might be expired (test quickly after sign in)
- Verify APPLE_CLIENT_ID environment variable matches your App ID
- Check backend logs for detailed error

### Issue: User not created in database
**Solution**:
- Check DynamoDB table permissions
- Verify Lambda has DynamoDB access
- Check CloudWatch logs for errors

### Issue: Mock authentication returns 404
**Solution**:
- Ensure X-Test-Auth header is exactly "nugget-test-2024"
- Verify backend is deployed with latest changes
- Check the endpoint URL is correct

## Next Steps

### For Google Sign In
1. Create Google Cloud Project and OAuth credentials
2. Install Google Sign-In SDK in iOS app
3. Implement signInWithGoogle() function
4. Test end-to-end flow

### For Production
1. Implement proper token refresh mechanism
2. Add analytics for sign-in events
3. Set up monitoring and alerts
4. Consider implementing:
   - Account deletion
   - Account linking (Apple + Google)
   - Email verification
   - Password reset (if adding email/password)

## Support

For issues or questions:
- Check CloudWatch Logs for backend errors
- Review Xcode console for iOS app errors
- Test with mock authentication first
- Verify all environment variables are set correctly