# GitHub Repository Setup Instructions

## Create the Repository on GitHub

1. Go to https://github.com/new
2. Repository name: `nugget`
3. Description: `Nugget – daily micro-learning from saved content`
4. Visibility: **Private**
5. **Do NOT** initialize with README, .gitignore, or license
6. Click "Create repository"

## Push Local Code to GitHub

Run these commands in the nugget directory:

```bash
git remote add origin git@github.com:Jachael/nugget.git
git branch -M main
git push -u origin main
```

## Verify

After pushing, you should see:
- 37 files
- Initial commit: "chore: initial Nugget MVP scaffold"
- Backend, iOS, and docs folders

## Next Steps

### For Backend
The backend is already deployed and running at:
- **Custom Domain**: https://api.nugget.jasontesting.com/v1
- **Direct URL**: https://esc8zwzche.execute-api.eu-west-1.amazonaws.com/v1

### For iOS App
1. Open Xcode
2. Create New Project (iOS App, SwiftUI)
3. Name: NuggetApp
4. Save in `ios/` directory
5. Replace generated files with provided Swift files in `ios/NuggetApp/NuggetApp/`

### Development Workflow
- Create feature branches for new work
- All changes via pull requests
- CI will run automatically on PRs

## Repository Secrets (for CI/CD)

When ready to add deployment from CI:

Go to Settings → Secrets and variables → Actions

Add:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `JWT_SECRET` (for production)

## Branch Protection (Optional but Recommended)

Settings → Branches → Add rule
- Branch name pattern: `main`
- ☑ Require pull request before merging
- ☑ Require status checks to pass before merging
  - Select: `test` (backend CI)
