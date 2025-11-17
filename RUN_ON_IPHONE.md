# 📱 Run Nugget on Your iPhone - Super Simple!

## You're Ready! Just 3 Steps:

### 1. Open Xcode
Double-click this file:
```
/Users/jason/nugget/ios/NuggetApp.xcodeproj
```

Or from Terminal:
```bash
open /Users/jason/nugget/ios/NuggetApp.xcodeproj
```

### 2. Configure Signing (One-Time Setup)
When Xcode opens:
1. Click on **NuggetApp** (blue icon at top of left sidebar)
2. Under **Targets**, select **NuggetApp**
3. Click **Signing & Capabilities** tab
4. Check ✅ **Automatically manage signing**
5. Select your **Team** (your Apple ID)
   - Don't have one? Click "Add Account" and sign in with your Apple ID

### 3. Run on iPhone
1. **Connect your iPhone** to your Mac with USB cable
2. **Unlock your iPhone**
3. In Xcode toolbar (top), click the device dropdown and **select your iPhone**
4. Click the **▶ Play button** (or press ⌘R)

**First time only**: On your iPhone:
- Go to: Settings → General → VPN & Device Management
- Tap your Apple ID under "Developer App"
- Tap **Trust**
- Go back to Xcode and click Play again

**The app will launch on your iPhone!** 🎉

## What You Can Do:

✅ **Sign In** - Tap "Sign In (Test Mode)" - no Apple ID needed!
✅ **Add Nuggets** - Tap Inbox → + button → paste any URL
✅ **AI Summaries** - Backend automatically generates summaries with Claude
✅ **Start Sessions** - Tap Home → "Start Learning Session"
✅ **Build Streaks** - Complete sessions to build your daily streak

## The App is LIVE!

- Connects to: `https://api.nugget.jasontesting.com/v1`
- Uses real AWS backend
- Claude AI summarization
- Your data persists in the cloud!

## Troubleshooting

**"Failed to code sign"**
→ Make sure you selected your Team in Signing & Capabilities

**"iPhone is not available"**
→ Make sure iPhone is unlocked and trusted

**App crashes on launch**
→ Check Xcode console (bottom panel) for errors
→ Make sure iPhone is running iOS 17+

**"Developer Mode required"** (iOS 16+)
→ Settings → Privacy & Security → Developer Mode → Turn On → Restart iPhone

That's it! You should be up and running in under 5 minutes.
