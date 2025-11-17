# Nugget API Documentation

## Base URL

**Production:** `https://api.nugget.jasontesting.com/v1`
**Dev:** `https://esc8zwzche.execute-api.eu-west-1.amazonaws.com/v1`

## Authentication

Most endpoints require a Bearer token obtained from the `/auth/apple` endpoint.

Include the token in the Authorization header:
```
Authorization: Bearer <your_access_token>
```

## Endpoints

### POST /auth/apple
Authenticate with Apple ID token and get an access token.

**Request:**
```json
{
  "idToken": "mock_test_user_123"
}
```

**Response:**
```json
{
  "userId": "usr_mock_test_user_123",
  "accessToken": "eyJhbGci...",
  "streak": 0
}
```

---

### POST /nuggets
Create a new nugget (requires auth).

**Request:**
```json
{
  "sourceUrl": "https://example.com/article",
  "sourceType": "url",
  "rawTitle": "Article Title",
  "rawText": "Optional excerpt",
  "category": "Technology"
}
```

**Response:**
```json
{
  "nuggetId": "uuid",
  "sourceUrl": "...",
  "status": "inbox",
  "createdAt": "2025-11-17T..."
}
```

---

### GET /nuggets
List nuggets (requires auth).

**Query Parameters:**
- `status` - Filter by status (inbox, completed, archived). Default: inbox
- `category` - Filter by category
- `limit` - Max number of results. Default: 50

**Response:**
```json
{
  "nuggets": [{
    "nuggetId": "uuid",
    "sourceUrl": "...",
    "status": "inbox",
    "summary": "AI-generated summary",
    "keyPoints": ["Point 1", "Point 2"],
    "question": "Reflection question?"
  }]
}
```

---

### PATCH /nuggets/{nuggetId}
Update a nugget (requires auth).

**Request:**
```json
{
  "status": "completed",
  "category": "Learning"
}
```

**Response:**
```json
{
  "success": true,
  "updated": { "status": "completed" }
}
```

---

### POST /sessions/start
Start a learning session (requires auth).

**Request:**
```json
{
  "size": 3,
  "category": null
}
```

**Response:**
```json
{
  "sessionId": "uuid",
  "nuggets": [...]
}
```

---

### POST /sessions/{sessionId}/complete
Complete a learning session (requires auth).

**Request:**
```json
{
  "completedNuggetIds": ["uuid1", "uuid2"]
}
```

**Response:**
```json
{
  "success": true,
  "completedCount": 2
}
```

## Error Responses

All endpoints may return error responses:

```json
{
  "error": "Error message"
}
```

Common status codes:
- `400` - Bad Request
- `401` - Unauthorized
- `404` - Not Found
- `500` - Internal Server Error
