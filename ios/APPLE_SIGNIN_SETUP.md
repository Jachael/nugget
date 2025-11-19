# Apple Sign-In Setup for Nugget App

## Prerequisites

1. **Apple Developer Account** (required)
2. **App ID with Sign In with Apple capability**
3. **Provisioning profiles updated**

## Step 1: Configure in Apple Developer Console

### Create/Update App ID

1. Go to [Apple Developer Console](https://developer.apple.com)
2. Navigate to **Certificates, Identifiers & Profiles** → **Identifiers**
3. Create or select your App ID (Bundle ID: `com.nugget.app` or your chosen ID)
4. Enable **Sign In with Apple** capability
5. Configure:
   - **Enable as a primary App ID** (checked)
   - Save changes

### Create Service ID (for Web/Backend)

1. In **Identifiers**, click **+** and select **Services IDs**
2. Create a new Service ID:
   - Description: "Nugget App Authentication"
   - Identifier: `com.nugget.app.service` (or similar)
3. Enable **Sign In with Apple**
4. Configure:
   - Primary App ID: Select your app's ID
   - Return URLs: Add `https://your-api-domain.com/auth/callback`
   - Domains: Add your API domain

### Create Private Key

1. Navigate to **Keys**
2. Click **+** to create a new key
3. Name: "Nugget Sign In with Apple"
4. Enable **Sign In with Apple**
5. Configure → Select your App ID
6. Download the key file (.p8)
7. Note the Key ID (you'll need this)

## Step 2: Configure in Xcode

### Add Capability

1. Open your project in Xcode
2. Select your app target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add **Sign In with Apple**

### Update Entitlements

The entitlement will be automatically added:
```xml
<key>com.apple.developer.applesignin</key>
<array>
    <string>Default</string>
</array>
```

### Implement Sign In UI

The app already has the Sign In with Apple button implemented in `LoginView.swift`. The flow:

1. User taps "Sign in with Apple" button
2. Apple authentication sheet appears
3. User authenticates with Face ID/Touch ID
4. App receives identity token
5. Token is sent to backend for validation
6. Backend exchanges for Cognito token and creates/updates user

## Step 3: Backend Configuration

### Update Cognito with Apple Provider

Run this command with your actual values:

```bash
aws cognito-idp create-identity-provider \
  --user-pool-id eu-west-1_1zILS9mOj \
  --provider-name SignInWithApple \
  --provider-type SignInWithApple \
  --provider-details \
    client_id=com.nugget.app,\
    team_id=YOUR_TEAM_ID,\
    key_id=YOUR_KEY_ID,\
    private_key="$(cat YOUR_KEY_FILE.p8)",\
    authorize_scopes="email name" \
  --attribute-mapping \
    email=email \
    name=name \
    username=sub \
  --region eu-west-1
```

Replace:
- `YOUR_TEAM_ID`: Your Apple Developer Team ID (found in Membership details)
- `YOUR_KEY_ID`: The Key ID from Step 1
- `YOUR_KEY_FILE.p8`: Path to your downloaded private key

### Update User Pool Client

```bash
aws cognito-idp update-user-pool-client \
  --user-pool-id eu-west-1_1zILS9mOj \
  --client-id 6roa95ol200brl6tsrlnkckpd6 \
  --supported-identity-providers COGNITO SignInWithApple \
  --region eu-west-1
```

## Step 4: Testing

### Local Development Testing

1. **Simulator Testing** (Limited):
   - Sign In with Apple UI will appear
   - But actual authentication won't work
   - Use mock token for development

2. **Device Testing** (Recommended):
   - Deploy to physical device
   - Must be signed with valid provisioning profile
   - Full Sign In with Apple flow works

### TestFlight Testing

1. Archive your app in Xcode
2. Upload to App Store Connect
3. Distribute via TestFlight
4. Test full authentication flow

## Step 5: Production Checklist

### Before Release

- [ ] Apple Sign In capability enabled in App ID
- [ ] Service ID configured with correct domains
- [ ] Private key securely stored (never commit to git)
- [ ] Cognito configured with Apple provider
- [ ] Backend validates Apple tokens properly
- [ ] Token refresh implemented
- [ ] Error handling for auth failures
- [ ] Privacy policy includes Sign In with Apple

### Environment Variables Needed

For backend (production):
```bash
COGNITO_USER_POOL_ID=eu-west-1_1zILS9mOj
COGNITO_CLIENT_ID=6roa95ol200brl6tsrlnkckpd6
USE_COGNITO=true
APPLE_TEAM_ID=YOUR_TEAM_ID
APPLE_KEY_ID=YOUR_KEY_ID
APPLE_PRIVATE_KEY=contents_of_p8_file
```

## Troubleshooting

### Common Issues

1. **"Sign In with Apple isn't available"**
   - Check capability is added in Xcode
   - Verify provisioning profile includes the capability
   - Ensure testing on iOS 13.0+

2. **"Invalid client" error**
   - Verify Bundle ID matches Apple configuration
   - Check Service ID is correctly configured
   - Ensure domains and return URLs are correct

3. **Token validation fails**
   - Verify private key is correct
   - Check Team ID and Key ID are accurate
   - Ensure token hasn't expired (valid for 10 minutes)

4. **User info not received**
   - User info (name, email) only provided on first sign-in
   - Subsequent sign-ins only provide user identifier
   - Store user info on first sign-in

## Security Considerations

1. **Never expose**:
   - Apple private key (.p8 file)
   - Cognito client secret
   - Raw Apple tokens in logs

2. **Always validate**:
   - Token signatures
   - Token expiration
   - Token audience (your app's bundle ID)

3. **Implement**:
   - Secure token storage (Keychain)
   - Token refresh before expiration
   - Logout/revocation handling

## Next Steps

1. Get Apple Developer account credentials
2. Configure App ID and Service ID
3. Download private key
4. Update Cognito configuration
5. Test on real device
6. Deploy to TestFlight for beta testing