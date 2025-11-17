# Nugget – MVP Scaffolding & Setup Guide

This document is written for an AI coding assistant (e.g. Claude Code) that:
- Has access to a terminal with `git`, `python`/`node`, `aws` CLI, and Xcode (for iOS work).
- Can read and modify files in this project directory.
- May call the AWS CLI using credentials already configured for the user.
- May or may not have the GitHub CLI `gh` installed.

The goal is to:
1. **Create the full Nugget MVP project scaffold from scratch.**
2. **Set up a private GitHub repository** and push the scaffolded project.
3. **Provision AWS serverless backend infrastructure** suitable for dev/prod.
4. **Connect the backend to a custom domain**: `nugget.jasontesting.com` via Route53.
5. **Prepare the iOS app scaffold** ready for implementation.
6. **Follow good software engineering practices** (structure, tests, CI).

The human owner of this project is Jason. The domain `jasontesting.com` is already owned and hosted in Route53.

---

## 0. High-Level System Overview

**Product:** Nugget – a daily micro‑learning app.

Core MVP capabilities:

- Users sign in with Apple (minimal personal data).
- Users can save links/content into Nugget (initially via the app; share extension to follow).
- Backend stores each saved item as a “nugget” and asynchronously calls an LLM to generate:
  - A short summary,
  - 2–4 key bullet points,
  - A simple reflection/comprehension question.
- The iOS app can start a “session” that serves a small set of nuggets to review.
- Streak and basic stats are tracked per user.

Constraints and preferences:

1. **Cheap & scalable** → AWS serverless, pay‑per‑use.
2. **Beautiful & minimal** → SwiftUI, “liquid glass” visual style.
3. **Minimum viable personal data** → Sign in with Apple, no unnecessary PII.
4. **Backend compatible with web & iOS** → Public HTTP/JSON API.
5. **Best‑practice engineering** → Clear structure, infra as code, tests, CI, secrets handled safely.

---

## 1. Repository & GitHub Setup

### 1.1 Local repo initialization

1. Create a new directory for the project (if not already inside one):

   ```bash
   mkdir -p nugget && cd nugget
   ```

2. Initialize git:

   ```bash
   git init
   ```

3. Create the base structure:

   ```bash
   mkdir -p docs backend/src/handlers backend/src/lib backend/test ios .github/workflows
   touch README.md
   ```

4. Move this scaffolding document into `docs/scaffolding.md` if it is not already there:

   ```bash
   mkdir -p docs
   mv scaffolding.md docs/scaffolding.md 2>/dev/null || true
   ```

### 1.2 GitHub repository creation

**Goal:** Create a private GitHub repo named `nugget` (or similar), add it as the remote, and push the initial scaffold.

Attempt the following steps in order:

1. **If the `gh` CLI is installed and authenticated:**

   ```bash
   gh repo create nugget --private --source=. --remote=origin --description "Nugget – daily micro-learning from saved content"
   ```

2. If `gh` is not available, fall back to:

   - Ask the human to create a private repo named `nugget` on GitHub.
   - Once created, set the remote (replace `<USER>`):

     ```bash
     git remote add origin git@github.com:<USER>/nugget.git
     ```

3. Make an initial commit and push:

   ```bash
   git add .
   git commit -m "chore: initial scaffold"
   git push -u origin main
   ```

> From this point on, all changes should be done on feature branches and merged via pull requests.


---

## 2. Desired Project Structure

Target structure for the repo (to be created by the assistant as needed):

```text
nugget/
  README.md
  docs/
    scaffolding.md
    architecture.md
    api.md
    privacy.md
    contributing.md

  backend/
    src/
      handlers/
        authApple.ts
        createNugget.ts
        listNuggets.ts
        startSession.ts
        completeSession.ts
        summariseNugget.ts
      lib/
        dynamo.ts
        auth.ts
        models.ts
        priority.ts
        llm.ts
    test/
      priority.test.ts
      auth.test.ts
    package.json
    tsconfig.json
    serverless.yml   # or CDK app; use Serverless Framework for simplicity

  ios/
    NuggetApp/       # Xcode project folder once generated
    NuggetShareExtension/

  .github/
    workflows/
      backend-ci.yml
      ios-ci.yml

  .editorconfig
  .gitignore
```

---

## 3. Backend Design

### 3.1 Tech choices

- Runtime: **Node.js + TypeScript** (preferred).
- Infra as Code: **Serverless Framework** using `serverless.yml` (simple for Lambda + API Gateway + DynamoDB).
- Data store: **DynamoDB** (on‑demand / pay-per-request).
- Auth: Sign in with Apple → verified on backend, internal `userId` used in DB.
- LLM: Placeholder integration for now; call out to Anthropic/OpenAI/Bedrock via HTTPS using an API key stored in environment variables (never committed).

### 3.2 Data model (DynamoDB)

Use 3 tables to start: `Users`, `Nuggets`, `Sessions`. All tables should default to **on‑demand billing**.

1. **Users table**  
   - Partition key: `userId` (string)
   - Attributes (minimal):
     - `userId`: internal UUID
     - `appleSub`: Apple subject/id
     - `createdAt`: number (Unix timestamp)
     - `lastActiveDate`: string (YYYY-MM-DD)
     - `streak`: number
     - `settings`: map

2. **Nuggets table**  
   - Partition key: `userId` (string)  
   - Sort key: `nuggetId` (string)
   - Attributes:
     - `sourceUrl`: string
     - `sourceType`: string (`url|tweet|linkedin|youtube|other`)
     - `rawTitle`: string
     - `rawText`: string (OPTIONAL, may store excerpt only)
     - `status`: string (`inbox|completed|archived`)
     - `category`: string (optional)
     - `summary`: string
     - `keyPoints`: list of strings
     - `question`: string
     - `priorityScore`: number
     - `createdAt`, `lastReviewedAt`, `timesReviewed`

3. **Sessions table**  
   - Partition key: `userId` (string)  
   - Sort key: `sessionId` (string)
   - Attributes:
     - `date`: string (YYYY-MM-DD)
     - `startedAt`, `completedAt`: numbers
     - `nuggetIds`: list
     - `completedCount`: number


### 3.3 Core API endpoints (HTTP/JSON)

Base path: `/v1`

Implement the following endpoints in the MVP:

1. **POST `/v1/auth/apple`**  
   - Body: `{ "idToken": "<apple_identity_token>" }`  
   - Behaviour:
     - Verify Apple token (can be stubbed in dev).
     - Look up or create `Users` record matching `appleSub`.
     - Return internal `userId` and a short‑lived **JWT accessToken** issued by this backend.
   - Response example:

     ```json
     {
       "userId": "usr_123",
       "accessToken": "<jwt>",
       "streak": 3
     }
     ```

2. **POST `/v1/nuggets`** – create nugget  
   - Auth: Bearer token required.
   - Body:

     ```json
     {
       "sourceUrl": "https://example.com/article",
       "sourceType": "url",
       "rawTitle": "Optional title",
       "rawText": "Optional snippet",
       "category": "Product"
     }
     ```

   - Behaviour:
     - Validate input.
     - Store initial nugget in DynamoDB with `status = "inbox"` and provisional `priorityScore`.
     - Enqueue async summarisation (via direct invocation of `summariseNugget` Lambda or SQS).
     - Return basic nugget object.

3. **GET `/v1/nuggets`** – list nuggets  
   - Query params:
     - `status` (optional, default `inbox`)
     - `category` (optional)
     - `limit`, `lastKey` (for pagination)
   - Returns: list of nugget summaries (no raw text necessary).

4. **PATCH `/v1/nuggets/{nuggetId}`**  
   - Update fields like `status`, `category`.

5. **POST `/v1/sessions/start`**  
   - Body: `{ "size": 3, "category": null }`  
   - Behaviour:
     - Select up to `size` nuggets from the user’s `inbox` ordered by `priorityScore` and `createdAt`.
     - Create a `Sessions` record.
     - Return the `sessionId` plus the selected nuggets.

6. **POST `/v1/sessions/{sessionId}/complete`**  
   - Body: `{ "completedNuggetIds": [...] }`
   - Behaviour:
     - Mark provided nuggets as `completed`, updating `lastReviewedAt` and `timesReviewed`.
     - Update user `streak` and `lastActiveDate` based on today’s date.
     - Mark the session as completed.


### 3.4 Priority scoring helper

Implement a helper function in `backend/src/lib/priority.ts`:

```ts
export function computePriorityScore(createdAt: number, timesReviewed: number): number {
  const now = Date.now() / 1000;
  const ageDays = Math.max((now - createdAt) / 86400, 1);
  const reviewPenalty = 1 + 0.5 * timesReviewed;
  return Math.log(ageDays + 1) / reviewPenalty;
}
```

Write tests in `backend/test/priority.test.ts` to validate basic behaviour.


### 3.5 LLM summarisation Lambda

Handler: `summariseNugget.ts`

- Triggered with payload `{ userId, nuggetId }`.
- Loads nugget from DB.
- Calls `llm.ts` helper to perform summarisation with a prompt like:

  > “Summarise the following content in 2–3 sentences, then list 3 key bullet points, then one simple reflective question. Return JSON with fields `summary`, `keyPoints`, `question`.”

- Writes results back to the `Nuggets` item.
- Recomputes `priorityScore` after summarisation.

`llm.ts` should read the LLM API key from environment variables and **must not** log or expose the key.


### 3.6 Serverless configuration

Create `backend/serverless.yml` that defines:

- Service name: `nugget`
- Provider: `aws`, runtime `nodejs18.x`, region (e.g. `eu-central-1` or `eu-west-1`).
- Environment variables for:
  - `NUGGET_USERS_TABLE`
  - `NUGGET_NUGGETS_TABLE`
  - `NUGGET_SESSIONS_TABLE`
  - `LLM_API_KEY` (value set via AWS console/SSM, not in code)
- Functions:
  - `authApple`
  - `createNugget`
  - `listNuggets`
  - `patchNugget`
  - `startSession`
  - `completeSession`
  - `summariseNugget`
- HTTP API events mapping the above routes.

DynamoDB tables should also be declared here with `billingMode: PAY_PER_REQUEST`.


### 3.7 Backend testing & CI

Set up `backend/package.json` with scripts:

```json
{
  "scripts": {
    "build": "tsc",
    "lint": "eslint src --ext .ts",
    "test": "jest",
    "deploy:dev": "serverless deploy --stage dev",
    "deploy:prod": "serverless deploy --stage prod"
  }
}
```

Create `.github/workflows/backend-ci.yml`:

- Trigger on pull requests affecting `backend/**`.
- Steps:
  - `npm install`
  - `npm run lint`
  - `npm test`


---

## 4. AWS & Domain Setup (Route53 + API Custom Domain)

**Goal:** Expose the backend under `https://api.nugget.jasontesting.com` (or `https://nugget.jasontesting.com/api`). For now we will do:

- API Gateway HTTP API
- Custom domain: `api.nugget.jasontesting.com` or `nugget-api.jasontesting.com`
- Route53 alias record pointing to the API Gateway domain.
- ACM certificate in the same region or in `us-east-1` depending on API Gateway type.

### 4.1 Preconditions

- The Route53 hosted zone for `jasontesting.com` already exists.
- The AWS CLI is authenticated against the correct account.

### 4.2 High-level steps for the assistant

1. Use AWS CLI to confirm the hosted zone:

   ```bash
   aws route53 list-hosted-zones-by-name --dns-name jasontesting.com
   ```

2. Use either Serverless custom domain plugin or manual CLI to:

   - Request an ACM certificate for `api.nugget.jasontesting.com`.
   - Validate it via DNS (create CNAME records in Route53).
   - Create an API Gateway custom domain for that hostname.
   - Map the API stage (`dev`, `prod`) to a base path (e.g., `/v1`).
   - Create an A/AAAA alias record in Route53 pointing to the API custom domain.

3. Document the final base URL in `docs/api.md` so iOS/web can read it.

> Note: exact commands depend on chosen API Gateway type and Serverless plugins. The assistant should choose a sane configuration and keep commands and infrastructure definitions in `serverless.yml` where possible.


---

## 5. iOS App Scaffold

### 5.1 Tech choices

- **Language:** Swift, using **SwiftUI**.
- **Minimum iOS version:** iOS 17 (reasonable assumption; can be adjusted).
- **Networking:** `URLSession` with async/await.
- **State:** ObservableObject view models.
- **Auth:** Sign in with Apple → retrieve Apple ID token → send to `/v1/auth/apple` → store `accessToken` securely.

### 5.2 Basic structure

Inside `ios/`, create an Xcode project named `NuggetApp` with:

```text
ios/
  NuggetApp/
    NuggetApp.xcodeproj
    NuggetApp/
      App/
        NuggetApp.swift
      Models/
        User.swift
        Nugget.swift
        Session.swift
      Services/
        APIClient.swift
        AuthService.swift
      ViewModels/
        HomeViewModel.swift
        SessionViewModel.swift
        InboxViewModel.swift
      Views/
        HomeView.swift
        SessionView.swift
        InboxView.swift
        NuggetDetailView.swift
        SettingsView.swift
  NuggetShareExtension/
    ... (can be scaffolded later)
```

### 5.3 Swift models

Use Codable models aligned with the backend API, e.g.:

```swift
struct Nugget: Identifiable, Codable {
    let id: String          // maps from nuggetId
    let sourceUrl: String
    let sourceType: String
    var title: String
    var category: String?
    var status: String
    var summary: String?
    var keyPoints: [String]?
    var question: String?
    var createdAt: Date
    var lastReviewedAt: Date?
    var timesReviewed: Int
}
```

Implement `CodingKeys` if the API uses different field names.


### 5.4 Screens to implement

1. **HomeView**
   - Shows greeting, streak, “Start Session” button.
   - Calls `/v1/sessions/start` and navigates to SessionView.

2. **SessionView**
   - Receives a list of `Nugget` objects.
   - Displays them as full‑screen cards with:
     - Title
     - Summary
     - Key bullet points
     - Question
   - Buttons: Skip, Done, Next.
   - On finish, call `/v1/sessions/{sessionId}/complete`.

3. **InboxView**
   - Calls `/v1/nuggets?status=inbox`.
   - Displays list of nuggets, grouped by category.
   - Tap → NuggetDetailView.

4. **NuggetDetailView**
   - Shows full summary, key points, question.
   - Actions: Mark complete, change category.

5. **SettingsView**
   - Manage sign out, notification time (just saved locally in MVP).


### 5.5 Networking layer

Create `APIClient` with generic request method, using base URL from a config:

```swift
struct APIConfig {
    static let baseURL = URL(string: "https://api.nugget.jasontesting.com/v1")!
}

final class APIClient {
    static let shared = APIClient()

    private init() {}

    func send<T: Decodable>(_ request: URLRequest, decodeTo type: T.Type) async throws -> T {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw APIError.invalidResponse
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
```

Auth tokens should be stored in Keychain and sent via `Authorization: Bearer <token>` headers.


### 5.6 iOS CI

Create `.github/workflows/ios-ci.yml` that:

- Triggers on PRs modifying `ios/**`.
- Runs `xcodebuild` to ensure the project builds and tests pass (with a minimal test target).


---

## 6. Share Extension (Outline Only for MVP)

For now, just scaffold the target; implementation can follow once the core app and API are solid.

Planned behaviour:

- Appears in iOS share sheet as “Save to Nugget”.
- Receives `URL` and optional text from the host app.
- Displays a small confirmation UI with optional category picker.
- Calls `POST /v1/nuggets` with `sourceUrl`, etc.
- Uses a shared app group or keychain access group to share auth token with main app.


---

## 7. Privacy & Minimal Data

Key principles (to be documented in `docs/privacy.md`):

- Store the **minimum** user data required to function:
  - internal `userId`
  - `appleSub`
  - usage stats (streak, counts)
  - content they intentionally save.
- Do **not** store:
  - precise location
  - device identifiers beyond those already implicit in standard logs
  - unnecessary PII (names, contacts, etc.) for the MVP.
- Ensure logs **never** contain:
  - auth tokens
  - LLM API keys
  - full raw content where not required.


---

## 8. Best Practices & Contribution Guidelines

Create `docs/contributing.md` with at least:

- Branch naming convention: `feature/...`, `fix/...`, `chore/...`.
- Require PRs into `main` with passing CI.
- Prefer small, focused PRs.
- Include or update tests for non‑trivial logic.
- Keep secrets out of the repo and out of AI prompts.


---

## 9. Suggested Initial Task List for the Coding Assistant

When ready to start implementing, perform these tasks in order (each on its own branch where possible):

1. **Set up Node/TypeScript backend project in `backend/`:**
   - Initialize `package.json`, `tsconfig.json`, ESLint, Jest.
   - Add basic `serverless.yml` with a `/health` endpoint.
   - Add `backend-ci.yml` workflow.

2. **Create DynamoDB tables & environment configuration via Serverless.**

3. **Implement data models (`models.ts`) and priority helper (`priority.ts` + tests).**

4. **Implement `/v1/auth/apple` stub handler that accepts a fake token in dev but is structured for real Apple verification.**

5. **Implement `/v1/nuggets` POST + GET handlers.**

6. **Implement `/v1/sessions/start` and `/v1/sessions/{id}/complete`.**

7. **Implement `summariseNugget` Lambda with a pluggable `llm.ts` module (real HTTP call can initially be mocked).**

8. **Deploy to a `dev` stage and verify end‑to‑end using curl or a small Postman collection.**

9. **Create the iOS SwiftUI project structure in `ios/NuggetApp`, including basic Views and ViewModels, and an initial buildable target.**

10. **Wire the iOS app to call the backend /health endpoint, then `/auth/apple` and `/nuggets` for a test user.**

11. **Add basic CI for iOS.**

12. **Optionally set up API custom domain `api.nugget.jasontesting.com` using Serverless or AWS CLI, update `APIConfig` in the iOS app.**


---

## 10. Important Safety & Security Notes for the Assistant

- Never commit secrets, API keys, or Apple credentials to the repo.
- Never echo or log secret values.
- Use environment variables and AWS SSM/Secrets Manager for secrets.
- If something requires manual configuration (e.g., Apple Developer console), clearly document the steps and wait for human input.


---

**End of scaffold.**  
This file should remain in `docs/scaffolding.md` and be updated if architecture evolves.
