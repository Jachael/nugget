# Nugget Architecture

## Overview

Nugget is a serverless application built on AWS with an iOS Swift UI client.

## System Components

```
┌─────────────┐
│  iOS App    │
│  (SwiftUI)  │
└──────┬──────┘
       │ HTTPS
       ▼
┌─────────────────────────────┐
│  API Gateway                │
│  api.nugget.jasontesting.com│
└──────────┬──────────────────┘
           │
    ┌──────┴──────────┬─────────┐
    ▼                 ▼         ▼
┌────────┐      ┌─────────┐   ┌────────────┐
│ Lambda │◄────►│DynamoDB │   │  Bedrock   │
│Functions│      │ Tables  │   │  Claude    │
└────────┘      └─────────┘   └────────────┘
```

## Backend Architecture

### API Layer
- **API Gateway (HTTP API)**: Routes requests to Lambda functions
- **Custom Domain**: api.nugget.jasontesting.com
- **Auth**: JWT tokens issued by backend

### Compute Layer
- **Lambda Functions**: Serverless compute
  - authApple - Handle authentication
  - createNugget - Save new content
  - listNuggets - Query saved content
  - patchNugget - Update content
  - startSession - Create learning session
  - completeSession - Process completed session
  - summariseNugget - Async LLM processing

### Data Layer
- **DynamoDB Tables** (On-Demand billing)
  - Users: User profiles and streaks
  - Nuggets: Saved content with AI summaries
  - Sessions: Learning session history

### AI Layer
- **AWS Bedrock**: Claude 3.5 Sonnet v2
- Generates summaries, key points, reflection questions
- Invoked asynchronously on nugget creation

## iOS Architecture

### Layered Structure

```
Views (SwiftUI)
      ↓
ViewModels (ObservableObject)
      ↓
Services (Business Logic)
      ↓
API Client (Networking)
      ↓
Models (Data Structures)
```

### Key Components

- **Services**
  - APIClient: HTTP communication
  - AuthService: Authentication flow
  - NuggetService: Content management
  - KeychainManager: Secure storage

- **Views**
  - HomeView: Dashboard with streak
  - SessionView: Learning cards
  - InboxView: Saved content list
  - NuggetDetailView: Individual nugget
  - SettingsView: User preferences

## Data Flow

### Creating a Nugget

1. User saves URL in iOS app
2. POST /nuggets → createNugget Lambda
3. Nugget saved to DynamoDB
4. summariseNugget Lambda invoked async
5. Bedrock generates summary
6. Nugget updated with AI content

### Learning Session

1. POST /sessions/start
2. Query nuggets by priority score
3. Return top N nuggets
4. User reviews in iOS app
5. POST /sessions/{id}/complete
6. Update nugget status, user streak

## Security

- HTTPS only communication
- JWT authentication (7-day expiry)
- Tokens stored in iOS Keychain
- AWS IAM roles for Lambda permissions
- No secrets in code

## Scalability

- Serverless auto-scaling
- DynamoDB on-demand capacity
- CDN for static assets (future)
- Read replicas (if needed)

## Monitoring

- CloudWatch Logs for Lambda
- API Gateway access logs
- DynamoDB metrics
- Custom metrics (future)

## Cost Optimization

- On-demand DynamoDB (pay-per-request)
- Lambda provisioned concurrency: None
- API caching (future optimization)
- Bedrock: Pay per token
