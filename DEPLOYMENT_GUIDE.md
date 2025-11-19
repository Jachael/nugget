# Step-by-Step Deployment Guide for Nugget App

## Prerequisites Checklist
- [ ] Apple Developer Account ($99/year)
- [ ] AWS Account (already have ✅)
- [ ] Xcode installed (already have ✅)
- [ ] Your Mac (for iOS development)

---

## Part 1: Apple Developer Setup (30 minutes)

### Step 1: Sign into Apple Developer
1. Go to https://developer.apple.com
2. Sign in with your Apple ID
3. If not enrolled, enroll in the Apple Developer Program

### Step 2: Create Your App ID
1. Navigate to **Certificates, Identifiers & Profiles**
2. Click **Identifiers** in the left sidebar
3. Click the **+** button to create a new identifier
4. Select **App IDs** → **App** → Continue
5. Fill in:
   - **Description**: Nugget App
   - **Bundle ID**: Select "Explicit"
   - **Enter Bundle ID**: `com.nugget.app` (or `com.yourname.nugget`)
6. Scroll down to **Capabilities**
7. Check: **Sign In with Apple**
8. Click **Continue** → **Register**

### Step 3: Note Your Team ID
1. Go to https://developer.apple.com/account
2. In the Membership section, find your **Team ID** (looks like: `ABCD1234EF`)
3. **Write this down** - you'll need it soon

---

## Part 2: Backend Deployment (10 minutes)

### Step 1: Deploy the Backend
```bash
cd /Users/jason/nugget/backend

# Build the TypeScript code
npm run build

# Deploy to AWS
npx serverless deploy --stage prod
```

Wait for deployment to complete. You'll see output like:
```
endpoints:
  POST - https://xxxxx.execute-api.eu-west-1.amazonaws.com/v1/auth/cognito
  GET - https://xxxxx.execute-api.eu-west-1.amazonaws.com/v1/nuggets
  ...
```

**IMPORTANT**: Copy the base URL (everything before `/v1`) - you'll need this for the iOS app.

### Step 2: Update iOS App with Production API
1. Open file: `/Users/jason/nugget/ios/NuggetApp/NuggetApp/Services/APIConfig.swift`
2. Update the production URL:
```swift
static let productionURL = "https://xxxxx.execute-api.eu-west-1.amazonaws.com/v1"
// Replace xxxxx with your actual API Gateway URL from above
```

---

## Part 3: Xcode Project Setup (20 minutes)

### Step 1: Open the Project
```bash
cd /Users/jason/nugget/ios/NuggetApp
open NuggetApp.xcodeproj
```

### Step 2: Configure Signing
1. In Xcode, select the **NuggetApp** project in the navigator
2. Select the **NuggetApp** target
3. Go to **Signing & Capabilities** tab
4. Check **Automatically manage signing**
5. **Team**: Select your Apple Developer account
6. **Bundle Identifier**: Change to something unique like:
   - `com.yourname.nugget` or
   - `com.yourdomain.nugget`
   - (Write this down - you'll need it)
7. Xcode will create the provisioning profile automatically

### Step 3: Add Sign In with Apple Capability
1. Still in **Signing & Capabilities**
2. Click **+ Capability** button
3. Search for "Sign In with Apple"
4. Double-click to add it
5. It should appear in your capabilities list

### Step 4: Update Version and Build
1. Go to **General** tab
2. **Version**: Keep as 1.0
3. **Build**: Set to 1

---

## Part 4: Create App in App Store Connect (15 minutes)

### Step 1: Access App Store Connect
1. Go to https://appstoreconnect.apple.com
2. Sign in with your Apple ID

### Step 2: Create New App
1. Click **My Apps**
2. Click the **+** button → **New App**
3. Fill in:
   - **Platforms**: iOS
   - **Name**: Nugget
   - **Primary Language**: English
   - **Bundle ID**: Select the one you created (com.yourname.nugget)
   - **SKU**: nugget-001 (or any unique identifier)
   - **User Access**: Full Access

### Step 3: App Information
1. Fill in basic information:
   - **Category**: Productivity or Education
   - **Content Rights**: Check the box
   - **Age Rating**: Click **Edit** and answer questionnaire (likely 4+)

### Step 4: Privacy Policy
For now, you can use a simple privacy policy:
1. Create a GitHub Gist with basic privacy policy
2. Or use a generator like: https://app-privacy-policy-generator.firebaseapp.com
3. Add the URL to App Store Connect

---

## Part 5: Build and Upload to TestFlight (15 minutes)

### Step 1: Select Device
1. In Xcode, at the top bar where it shows device selection
2. Change from simulator to **Any iOS Device (arm64)**

### Step 2: Archive the App
1. In Xcode menu: **Product** → **Archive**
2. Wait for build to complete (2-5 minutes)
3. The Organizer window will open automatically

### Step 3: Upload to App Store Connect
1. In Organizer, select your archive
2. Click **Distribute App**
3. Select **App Store Connect** → Next
4. Select **Upload** → Next
5. Keep all default options → Next
6. **Automatically manage signing** → Next
7. Review and click **Upload**

### Step 4: Wait for Processing
1. Upload takes 2-5 minutes
2. Processing takes 5-15 minutes
3. You'll get an email when it's ready

---

## Part 6: Configure TestFlight (10 minutes)

### Step 1: Go to TestFlight
1. In App Store Connect, select your app
2. Click **TestFlight** tab
3. Your build should appear (may take 10-15 minutes)

### Step 2: Add Test Information
1. Click on the build number
2. Fill in **Test Information**:
   - **What to Test**: "Please test the login flow and basic app functionality"
3. Answer Export Compliance: **No** (unless you use encryption)

### Step 3: Create Test Group
1. In TestFlight, click **+** next to **Groups**
2. Name it "Beta Testers"
3. Click **+** to add testers
4. Enter email addresses of testers
5. They'll receive an invitation

### Step 4: Install TestFlight
1. On your iPhone, download **TestFlight** from App Store
2. Open invitation email on your iPhone
3. Tap the link to join beta
4. Install the app through TestFlight

---

## Part 7: Test the App (5 minutes)

### Testing Checklist:
- [ ] App launches without crashing
- [ ] Splash screen animation works
- [ ] Sign in with Apple button appears
- [ ] Can authenticate (will use mock for now)
- [ ] Can navigate through all tabs
- [ ] Can add nuggets
- [ ] Theme switching works

---

## Troubleshooting

### Common Issues:

**"No account for team" error in Xcode**
- Make sure you're signed into Xcode with your Apple ID
- Xcode → Preferences → Accounts → Add Apple ID

**"Bundle ID already exists"**
- Change to something unique like `com.yourfirstname-lastname.nugget`

**Archive option is grayed out**
- Make sure you've selected "Any iOS Device" not a simulator

**Build fails with signing error**
- Let Xcode automatically manage signing
- Make sure you've selected your team

**TestFlight build not appearing**
- Wait 15-20 minutes after upload
- Check email for any issues from Apple

**"Missing Compliance" in TestFlight**
- Go to build → Provide Export Compliance Information
- Select "No" for encryption (unless you added encryption)

---

## What You Need to Do Right Now:

### Today (1 hour):
1. **Sign into Apple Developer** (or enroll if needed)
2. **Create App ID** with Sign In with Apple capability
3. **Note your Team ID**
4. **Deploy backend** with the commands above
5. **Update API URL** in iOS app
6. **Configure Xcode** project with your account
7. **Archive and upload** to TestFlight

### This Week:
1. Test on TestFlight
2. Fix any issues
3. Configure real Apple Sign-In (optional for testing)
4. Invite beta testers

### Before App Store Release:
1. Configure proper Apple Sign-In with Cognito
2. Add app screenshots
3. Write app description
4. Submit for review

---

## Quick Command Reference:

```bash
# Backend deployment
cd /Users/jason/nugget/backend
npm run build
npx serverless deploy --stage prod

# Open iOS project
cd /Users/jason/nugget/ios/NuggetApp
open NuggetApp.xcodeproj

# After making iOS changes, archive:
# Xcode: Product → Archive → Distribute App
```

---

## Need Help?

If you get stuck at any step:
1. The error messages are usually helpful
2. Most issues are signing/certificate related
3. Make sure Bundle IDs match everywhere
4. TestFlight processing can take up to 24 hours (usually 15 minutes)

You've got this! The app is ready - you just need to push it through the Apple pipeline.