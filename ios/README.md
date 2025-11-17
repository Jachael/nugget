# Nugget iOS App

## Setup

### Creating the Xcode Project

The Swift source files are provided in `NuggetApp/NuggetApp/`. To create the Xcode project:

1. Open Xcode
2. Create New Project → iOS → App
3. Product Name: `NuggetApp`
4. Interface: SwiftUI
5. Language: Swift
6. Save in: `ios/NuggetApp/`
7. Replace the generated files with the provided Swift files

### File Structure

```
NuggetApp/
├── App/
│   └── NuggetApp.swift          # Main app entry point
├── Models/
│   ├── User.swift               # User and auth models
│   ├── Nugget.swift             # Nugget data model
│   └── Session.swift            # Session models
├── Services/
│   ├── APIConfig.swift          # API configuration
│   ├── APIClient.swift          # HTTP client
│   ├── AuthService.swift        # Authentication
│   ├── NuggetService.swift      # Nugget management
│   └── KeychainManager.swift    # Secure storage
├── ViewModels/
│   └── (To be implemented)
└── Views/
    └── (To be implemented)
```

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Configuration

The app connects to: `https://api.nugget.jasontesting.com/v1`

For local testing, you can override the API URL via environment variable:
```swift
API_BASE_URL=https://localhost:3000/v1
```

## Features

### Implemented
- ✅ Data models
- ✅ API client with authentication
- ✅ Keychain secure storage
- ✅ Auth service with mock token support

### To Implement
- ⏳ SwiftUI views
- ⏳ View models
- ⏳ Sign in with Apple integration
- ⏳ Share extension
- ⏳ Local notifications
- ⏳ Widget

## Testing

### Mock Authentication

For local testing without Apple Sign In:
```swift
try await authService.signInWithMockToken()
```

### API Testing

Test the backend directly:
```bash
curl -X POST https://api.nugget.jasontesting.com/v1/auth/apple \
  -H "Content-Type: application/json" \
  -d '{"idToken": "mock_test_user"}'
```

## Development Notes

- All network calls use async/await
- Authentication tokens stored in Keychain
- JWT tokens valid for 7 days
- Auto-retry logic not yet implemented
- Error handling can be enhanced

## Next Steps

1. Create ViewModels for each screen
2. Implement SwiftUI views
3. Add proper error handling UI
4. Implement Sign in with Apple
5. Add loading states and animations
6. Write unit tests for ViewModels
7. Write UI tests for critical flows
