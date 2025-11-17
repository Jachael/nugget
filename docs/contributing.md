# Contributing to Nugget

## Development Workflow

1. **Branch Naming**
   - `feature/description` - New features
   - `fix/description` - Bug fixes
   - `chore/description` - Maintenance tasks

2. **Pull Requests**
   - All changes must go through PR review
   - PRs must have passing CI checks
   - Keep PRs focused and small

3. **Commit Messages**
   - Use conventional commits format
   - Examples: `feat:`, `fix:`, `chore:`, `docs:`

## Backend Development

```bash
cd backend
npm install
npm run build
npm test
npm run lint
```

## iOS Development

Open `ios/NuggetApp/NuggetApp.xcodeproj` in Xcode.

## Testing

- Backend: Write Jest tests for all business logic
- iOS: Write XCTest unit tests for ViewModels

## Secrets Management

- Never commit secrets or API keys
- Use environment variables for configuration
- Backend secrets via AWS SSM/Secrets Manager
- iOS secrets via Keychain

## Code Style

- Backend: Follow ESLint configuration
- iOS: Follow Swift style guide
- Use meaningful variable names
- Add comments for complex logic
