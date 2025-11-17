# Getting Started - Run Nugget on Your iPhone

## Quick Start (5-10 minutes)

### Step 1: Create Xcode Project

1. **Open Xcode** (make sure you have Xcode 15+ installed)

2. **Create New Project**:
   - File → New → Project
   - Choose **iOS** → **App**
   - Click **Next**

3. **Configure Project**:
   - Product Name: `NuggetApp`
   - Team: Select your Apple Developer account (or create free account)
   - Organization Identifier: `com.yourname.nugget` (or similar)
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Storage: **None**
   - Click **Next**

4. **Save Location**:
   - Navigate to: `/Users/jason/nugget/ios/`
   - Click **Create**

### Step 2: Replace Generated Files

Xcode will create a basic project. Now replace the files with our complete implementation:

1. **In Xcode's Project Navigator** (left sidebar), you'll see:
   - NuggetApp/
     - NuggetApp/
       - NuggetAppApp.swift (delete this)
       - ContentView.swift (delete this)
       - Assets.xcassets (keep)
       - Preview Content/ (keep)

2. **Delete the generated files**:
   - Right-click `NuggetAppApp.swift` → Delete → Move to Trash
   - Right-click `ContentView.swift` → Delete → Move to Trash

3. **Add our folders**:
   - In Finder, navigate to: `/Users/jason/nugget/ios/NuggetApp/NuggetApp/`
   - Drag these folders into Xcode's NuggetApp group:
     - App/
     - Models/
     - Services/
     - Views/
   - When prompted, choose:
     - ✅ Copy items if needed
     - ✅ Create groups
     - Add to targets: ✅ NuggetApp

### Step 3: Configure Signing

1. **Select the project** (blue icon at top of navigator)
2. Select **NuggetApp** target
3. Click **Signing & Capabilities** tab
4. **Enable "Automatically manage signing"**
5. Select your **Team** (Apple ID)

The bundle identifier should be unique (e.g., `com.jason.NuggetApp`)

### Step 4: Run on Your iPhone

1. **Connect your iPhone** via USB cable

2. **Trust your Mac**:
   - On iPhone: Settings → General → VPN & Device Management
   - Trust your computer if prompted

3. **Select your iPhone** as the run destination:
   - Click the device dropdown (top toolbar in Xcode)
   - Select your iPhone from the list

4. **Build and Run**:
   - Click the **▶ Play** button (or press ⌘R)
   - First time: You'll need to **trust the developer** on iPhone:
     - Settings → General → VPN & Device Management
     - Under "Developer App", tap your Apple ID
     - Tap "Trust"
   - Run again from Xcode

5. **The app should launch!**

## Using the App

### First Launch
1. Tap **"Sign In (Test Mode)"** - uses mock authentication
2. You'll see the home screen with your streak (starts at 0)

### Add Your First Nugget
1. Tap **Inbox** tab
2. Tap **+** button
3. Enter a URL (e.g., `https://example.com/article`)
4. Optionally add a title and category
5. Tap **Save**

**Note**: The backend will automatically generate a summary using Claude AI within a few seconds. Pull down to refresh the list to see the AI-generated content!

### Start a Learning Session
1. Go to **Home** tab
2. Tap **"Start Learning Session"**
3. Swipe through nuggets
4. For each one:
   - Read the summary
   - Review key points
   - Think about the reflection question
   - Tap **Done** or **Skip**
5. Complete the session to increase your streak!

### Settings
- View your user ID
- Check your current streak
- Sign out (clears local data)

## Troubleshooting

### "Failed to load nuggets"
- Check that your iPhone has internet connection
- The backend is at: `https://api.nugget.jasontesting.com/v1`
- Try signing out and back in

### Build Errors in Xcode
- Make sure all files are properly added to the target
- Product → Clean Build Folder (⌘⇧K)
- Try building again

### "Untrusted Developer" on iPhone
- Settings → General → VPN & Device Management
- Find your developer certificate
- Tap "Trust"

### App Crashes on Launch
- Check Xcode console for error messages
- Make sure you're using iOS 17.0 or later
- Try restarting Xcode and your iPhone

## What You Can Test

✅ **Authentication**: Mock sign-in (no Apple ID required for testing)
✅ **Create Nuggets**: Save URLs with titles/categories
✅ **AI Summarization**: Claude generates summaries automatically
✅ **List View**: Browse your saved nuggets
✅ **Learning Sessions**: Review nuggets in card format
✅ **Streak Tracking**: Complete sessions to build streaks
✅ **Settings**: View account info and sign out

## Live Backend

The app connects to the real, deployed backend:
- API: `https://api.nugget.jasontesting.com/v1`
- LLM: Claude 3.5 Sonnet via AWS Bedrock
- Database: DynamoDB in eu-west-1

Your data is saved to the cloud and will persist across app launches!

## Advanced: Testing with Multiple Devices

Each mock sign-in creates a unique user. To use the same account:
1. Sign in on first device
2. Note the User ID from Settings
3. On second device, you'd need to modify the code to use the same token

For now, each device gets its own test account.

## Next Steps

Once you've tested the basic functionality:
- Implement real Apple Sign In
- Add pull-to-refresh for inbox
- Add edit/delete functionality
- Implement share extension
- Add local notifications
- Create widgets

## Need Help?

Check the error messages in:
- Xcode console (bottom panel when running)
- iPhone Settings → Privacy & Security → Analytics & Improvements → Analytics Data

The app has detailed error messages that will help debug issues.
