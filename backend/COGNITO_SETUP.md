# AWS Cognito Authentication Setup

## Overview
The app now uses AWS Cognito for user authentication with support for Apple Sign-In and Google Sign-In.

## Cognito Configuration

### User Pool
- **Pool ID**: `eu-west-1_1zILS9mOj`
- **Region**: `eu-west-1` (Ireland)
- **Pool Name**: `nugget-user-pool`

### iOS App Client
- **Client ID**: `6roa95ol200brl6tsrlnkckpd6`
- **Client Secret**: `egdc9kbp0gas62dd5nn6s3rip38fq7mn7eebspckia0g7bmfjlu`
- **Callback URL**: `nuggetapp://auth`
- **Sign Out URL**: `nuggetapp://signout`

## Apple Sign-In Setup

### Prerequisites
1. Apple Developer Account
2. App ID with Sign In with Apple capability enabled
3. Service ID for Sign In with Apple
4. Private key for Sign In with Apple

### Steps to Configure Apple Sign-In

1. **In Apple Developer Console**:
   - Create an App ID (if not already done): `com.nugget.app`
   - Enable "Sign In with Apple" capability
   - Create a Service ID for web authentication
   - Create a private key for Sign In with Apple

2. **Configure Cognito Identity Provider**:
   ```bash
   aws cognito-idp create-identity-provider \
     --user-pool-id eu-west-1_1zILS9mOj \
     --provider-name SignInWithApple \
     --provider-type SignInWithApple \
     --provider-details \
       client_id=com.nugget.app,\
       team_id=YOUR_TEAM_ID,\
       key_id=YOUR_KEY_ID,\
       private_key="YOUR_PRIVATE_KEY",\
       authorize_scopes="email name" \
     --attribute-mapping email=email,name=name,username=sub \
     --region eu-west-1
   ```

3. **Update App Client**:
   ```bash
   aws cognito-idp update-user-pool-client \
     --user-pool-id eu-west-1_1zILS9mOj \
     --client-id 6roa95ol200brl6tsrlnkckpd6 \
     --supported-identity-providers COGNITO SignInWithApple \
     --region eu-west-1
   ```

## Google Sign-In Setup

### Prerequisites
1. Google Cloud Console project
2. OAuth 2.0 Client ID for iOS
3. OAuth consent screen configured

### Steps to Configure Google Sign-In

1. **In Google Cloud Console**:
   - Create a new project or use existing
   - Enable Google Sign-In API
   - Create OAuth 2.0 credentials for iOS
   - Note the Client ID

2. **Configure Cognito Identity Provider**:
   ```bash
   aws cognito-idp create-identity-provider \
     --user-pool-id eu-west-1_1zILS9mOj \
     --provider-name Google \
     --provider-type Google \
     --provider-details \
       client_id=YOUR_GOOGLE_CLIENT_ID,\
       client_secret=YOUR_GOOGLE_CLIENT_SECRET,\
       authorize_scopes="openid email profile" \
     --attribute-mapping email=email,name=name,username=sub \
     --region eu-west-1
   ```

3. **Update App Client**:
   ```bash
   aws cognito-idp update-user-pool-client \
     --user-pool-id eu-west-1_1zILS9mOj \
     --client-id 6roa95ol200brl6tsrlnkckpd6 \
     --supported-identity-providers COGNITO SignInWithApple Google \
     --region eu-west-1
   ```

## iOS App Integration

### Using AWS Amplify (Recommended)

1. **Add AWS Amplify to your iOS project**:
   ```swift
   // In Package.swift or via SPM
   .package(url: "https://github.com/aws-amplify/amplify-swift", from: "2.0.0")
   ```

2. **Configure Amplify**:
   ```swift
   import Amplify
   import AWSCognitoAuthPlugin

   // In App init
   do {
       try Amplify.add(plugin: AWSCognitoAuthPlugin())
       try Amplify.configure()
   } catch {
       print("Failed to initialize Amplify: \(error)")
   }
   ```

3. **Create amplifyconfiguration.json**:
   ```json
   {
     "auth": {
       "plugins": {
         "awsCognitoAuthPlugin": {
           "IdentityManager": {
             "Default": {}
           },
           "CognitoUserPool": {
             "Default": {
               "PoolId": "eu-west-1_1zILS9mOj",
               "AppClientId": "6roa95ol200brl6tsrlnkckpd6",
               "AppClientSecret": "egdc9kbp0gas62dd5nn6s3rip38fq7mn7eebspckia0g7bmfjlu",
               "Region": "eu-west-1"
             }
           },
           "Auth": {
             "Default": {
               "authenticationFlowType": "USER_SRP_AUTH",
               "socialProviders": ["SignInWithApple", "Google"],
               "usernameAttributes": ["EMAIL"],
               "signupAttributes": ["EMAIL"],
               "passwordProtectionSettings": {
                 "passwordPolicyMinLength": 8,
                 "passwordPolicyCharacters": []
               },
               "mfaConfiguration": "OFF",
               "mfaTypes": [],
               "verificationMechanisms": ["EMAIL"]
             }
           }
         }
       }
     }
   }
   ```

### Direct Implementation (Current Approach)

The app currently uses Apple's Sign In with Apple button directly and sends the token to our backend. To integrate with Cognito:

1. **Continue using native Apple Sign-In button**
2. **Exchange Apple token for Cognito token**:
   - Send Apple ID token to `/v1/auth/cognito` endpoint
   - Backend validates and returns Cognito tokens
   - Store Cognito ID token in Keychain
   - Use Cognito ID token for all API calls

## Backend Integration

### Token Validation
All API endpoints now validate both:
1. Cognito ID tokens (primary)
2. Legacy JWT tokens (for backward compatibility)

### User Migration
- Existing users are automatically migrated when they sign in
- User data (streak, preferences) is preserved
- New `cognitoSub` field links Cognito identity to user profile

## Testing

### Local Testing
1. Use the mock token flow for development
2. Backend accepts mock tokens in dev environment

### Production Testing
1. Configure Apple Sign-In with real Apple Developer account
2. Test on real device (Sign In with Apple requires real device)
3. Verify token exchange and API authentication

## Security Notes

1. **Never commit**:
   - Client Secret
   - Apple private keys
   - Google client secrets

2. **Use environment variables** for sensitive data in production

3. **Token expiration**:
   - Cognito ID tokens expire after 1 hour
   - Refresh tokens expire after 30 days
   - Implement token refresh in the app

## Troubleshooting

### Common Issues

1. **"Invalid token" error**:
   - Check token is being sent in Authorization header
   - Verify token hasn't expired
   - Check Cognito User Pool ID and Client ID match

2. **Apple Sign-In not working**:
   - Verify bundle ID matches Apple configuration
   - Check entitlements include Sign In with Apple
   - Ensure testing on real device

3. **Google Sign-In not working**:
   - Verify OAuth client ID is correct
   - Check redirect URIs are configured
   - Ensure consent screen is published

## Next Steps

1. Configure Apple Sign-In in Apple Developer Console
2. Configure Google Sign-In in Google Cloud Console
3. Update iOS app to use Cognito tokens
4. Test end-to-end authentication flow
5. Deploy to TestFlight