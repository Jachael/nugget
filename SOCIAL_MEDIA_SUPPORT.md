# Social Media URL Support

## Overview
The Nugget app now supports automatic detection and scraping of LinkedIn and Twitter/X posts, in addition to regular web articles.

## Supported Platforms

### LinkedIn
- **Post URLs**: `linkedin.com/posts/*`
- **Articles**: `linkedin.com/pulse/*`
- **Feed items**: `linkedin.com/feed/*`
- **Auto-categorized**: Career

### Twitter/X
- **Tweet URLs**: `twitter.com/*/status/*`
- **X.com URLs**: `x.com/*/status/*`
- **Auto-detects**: Author name from meta tags
- **Note**: Thread detection (shows warning for multi-tweet threads)

### YouTube
- **Video URLs**: `youtube.com/watch?v=*`
- **Short URLs**: `youtu.be/*`
- **Note**: Currently detected but uses standard scraping

## How It Works

### Backend (Scraping)

1. **URL Type Detection**:
   - Automatically detects platform based on URL pattern
   - Routes to specialized scraping functions

2. **LinkedIn Scraping**:
   - Extracts from Open Graph meta tags
   - Gets title, description, and author info
   - Falls back to meta description if dynamic content not available
   - Default category: "career"

3. **Twitter/X Scraping**:
   - Extracts tweet content from meta tags
   - Parses author name from title
   - Adds thread warning for status URLs
   - Smart category detection based on content

4. **Fallback Handling**:
   - If scraping fails, provides helpful message
   - Users can manually add text content

### iOS App (UI)

1. **Automatic Detection**:
   - Detects URL type as user types/pastes
   - Shows platform-specific icon:
     - LinkedIn: 🔗 (link.circle.fill)
     - Twitter/X: @ (at.circle.fill)
     - YouTube: ▶️ (play.rectangle.fill)
     - General: 🌐 (globe)

2. **Source Type Setting**:
   - Automatically sets correct `sourceType` for API
   - No user action required

## Implementation Details

### Backend Files Modified:
- `/backend/src/lib/scraper.ts` - Enhanced scraping logic
- `/backend/src/handlers/createNugget.ts` - Already supports social types

### iOS Files Modified:
- `/ios/NuggetApp/NuggetApp/Views/InboxView.swift` - URL detection and icons

## Testing URLs

### LinkedIn Examples:
```
https://www.linkedin.com/posts/username_post-id
https://www.linkedin.com/pulse/article-title-author-name
https://www.linkedin.com/feed/update/urn:li:activity:123456
```

### Twitter/X Examples:
```
https://twitter.com/username/status/1234567890
https://x.com/username/status/1234567890
```

## Limitations

### Current Limitations:
1. **Dynamic Content**: Both LinkedIn and Twitter load content dynamically with JavaScript
2. **Authentication**: Some content requires login to view
3. **Rate Limiting**: Platforms may limit scraping requests
4. **Threads**: Twitter threads only capture the linked tweet

### Workarounds:
- Meta tags provide basic content (usually sufficient for summaries)
- Users can manually paste content if scraping fails
- AI summarization works with whatever content is extracted

## Future Improvements

Potential enhancements:
1. **Headless Browser**: Use Puppeteer for dynamic content
2. **API Integration**: Use official APIs (requires API keys)
3. **Thread Support**: Capture full Twitter threads
4. **More Platforms**:
   - Reddit posts
   - Medium articles
   - Instagram posts
   - TikTok videos

## Usage

### For Users:
1. Copy any LinkedIn or Twitter/X URL
2. Paste in the app
3. App automatically detects type
4. Content is scraped and saved
5. AI processes during session

### For Developers:
```javascript
// Backend automatically detects and scrapes
const scrapedContent = await scrapeUrl('https://twitter.com/user/status/123');
// Returns: { title, description, content, suggestedCategory }

// iOS automatically detects type
let sourceType = detectSourceType(from: urlString)
// Returns: "linkedin", "tweet", "youtube", or "url"
```

## API Endpoint

POST `/v1/nuggets`
```json
{
  "sourceUrl": "https://linkedin.com/posts/example",
  "sourceType": "linkedin",  // Auto-detected by iOS app
  "rawTitle": "Optional override",
  "category": "Optional override"
}
```

The backend will:
1. Detect the URL type
2. Use appropriate scraping method
3. Extract available content
4. Suggest category
5. Save for later AI processing