import https from 'https';
import http from 'http';

export interface ScrapedContent {
  title: string;
  description?: string;
  content: string;
  suggestedCategory?: string;
}

/**
 * Fetch URL content using Node.js http/https modules
 */
function fetchUrl(url: string): Promise<string> {
  return new Promise((resolve, reject) => {
    const client = url.startsWith('https') ? https : http;

    client.get(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      },
    }, (res) => {
      if (res.statusCode !== 200) {
        // For Twitter/X, we'll handle this specially
        if ((url.includes('twitter.com') || url.includes('x.com')) &&
            (res.statusCode === 400 || res.statusCode === 401 || res.statusCode === 403 || res.statusCode === 500)) {
          // Return empty HTML for Twitter so we can handle with fallback
          resolve('<!DOCTYPE html><html><head></head><body></body></html>');
          return;
        }
        reject(new Error(`Failed to fetch URL: ${res.statusCode} ${res.statusMessage}`));
        return;
      }

      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        resolve(data);
      });
    }).on('error', (err) => {
      reject(err);
    });
  });
}

/**
 * Extract text content from HTML string
 */
function extractText(html: string, tag: string): string {
  const regex = new RegExp(`<${tag}[^>]*>([\\s\\S]*?)</${tag}>`, 'i');
  const match = html.match(regex);
  return match ? match[1].replace(/<[^>]+>/g, '').trim() : '';
}

/**
 * Extract attribute from meta tag
 */
function extractMetaContent(html: string, property: string, attribute: string = 'property'): string {
  const regex = new RegExp(`<meta\\s+${attribute}=["']${property}["']\\s+content=["']([^"']+)["']`, 'i');
  const match = html.match(regex);
  return match ? match[1] : '';
}

/**
 * Detect the type of URL
 */
function detectUrlType(url: string): 'linkedin' | 'twitter' | 'general' {
  const urlLower = url.toLowerCase();

  if (urlLower.includes('linkedin.com/posts/') || urlLower.includes('linkedin.com/pulse/') || urlLower.includes('linkedin.com/feed/')) {
    return 'linkedin';
  }

  if (urlLower.includes('twitter.com/') || urlLower.includes('x.com/')) {
    return 'twitter';
  }

  return 'general';
}

/**
 * Scrape LinkedIn posts
 */
async function scrapeLinkedIn(_url: string, html: string): Promise<ScrapedContent> {
  // LinkedIn posts load content dynamically, but we can get basic info from meta tags
  const title = extractMetaContent(html, 'og:title') || 'LinkedIn Post';
  const description = extractMetaContent(html, 'og:description') || '';

  // Try to extract the main content from LinkedIn's structure
  // LinkedIn uses specific class names for post content
  let content = description;

  // Try to find the actual post content (LinkedIn often puts it in meta description)
  // For better results, we'd need a headless browser, but this works for basic content
  const articleBody = html.match(/<div[^>]*class="[^"]*feed-shared-text[^"]*"[^>]*>([\s\S]*?)<\/div>/i);
  if (articleBody) {
    content = articleBody[1].replace(/<[^>]+>/g, '').trim();
  }

  // If still no content, use the meta description
  if (!content || content.length < 50) {
    content = description;
  }

  // Extract author if available
  const author = extractMetaContent(html, 'article:author', 'property') ||
                 extractMetaContent(html, 'og:article:author') || '';

  if (author) {
    content = `Author: ${author}\n\n${content}`;
  }

  return {
    title: title.substring(0, 200),
    description: description.substring(0, 300),
    content: content || 'LinkedIn content requires authentication to access. Please copy the text manually.',
    suggestedCategory: 'career', // LinkedIn is primarily career-focused
  };
}

/**
 * Scrape Twitter/X posts - simplified fallback approach
 */
async function scrapeTwitterFromFxTwitter(originalUrl: string, html: string): Promise<ScrapedContent> {
  // Try to extract from any available meta tags first
  const title = extractMetaContent(html, 'og:title') ||
                extractMetaContent(html, 'twitter:title', 'name') || '';

  let description = extractMetaContent(html, 'og:description') ||
                    extractMetaContent(html, 'twitter:description', 'name') || '';

  // If we got meta tags, use them
  if (title || description) {
    const authorMatch = title.match(/@(\w+)/);
    const author = authorMatch ? authorMatch[1] : '';

    let content = description || title;

    if (author && !content.includes(`@${author}`)) {
      content = `@${author}: ${content}`;
    }

    return {
      title: author ? `Tweet by @${author}` : title || 'Tweet',
      description: description.substring(0, 300),
      content,
      suggestedCategory: suggestCategoryFromContent(content),
    };
  }

  // Fallback: Extract username and tweet ID from URL for manual entry prompt
  const urlMatch = originalUrl.match(/(?:twitter\.com|x\.com)\/(\w+)\/status\/(\d+)/);
  const username = urlMatch ? urlMatch[1] : 'unknown';
  const tweetId = urlMatch ? urlMatch[2] : '';

  // Provide a helpful message with the username
  const fallbackContent = `Tweet from @${username}\n\n` +
    `[Please paste the tweet text here]\n\n` +
    `Note: Twitter/X no longer allows automatic content extraction. ` +
    `Please copy the tweet text from your browser and update this nugget.`;

  return {
    title: `Tweet by @${username}`,
    description: `Tweet ID: ${tweetId}`,
    content: fallbackContent,
    suggestedCategory: undefined, // Can't categorize without content
  };
}


/**
 * Simple content-based category suggestion
 */
function suggestCategoryFromContent(content: string): string | undefined {
  const textLower = content.toLowerCase();

  // Check for category keywords
  const categories = {
    technology: ['tech', 'ai', 'software', 'coding', 'startup', 'app'],
    finance: ['stock', 'market', 'crypto', 'investment', 'trading'],
    sport: ['sport', 'game', 'match', 'player', 'team'],
    career: ['job', 'hiring', 'career', 'work', 'professional'],
    science: ['research', 'study', 'science', 'discovery'],
    health: ['health', 'fitness', 'wellness', 'medical'],
    business: ['business', 'company', 'revenue', 'startup'],
  };

  for (const [category, keywords] of Object.entries(categories)) {
    for (const keyword of keywords) {
      if (textLower.includes(keyword)) {
        return category;
      }
    }
  }

  return undefined;
}

/**
 * Convert Twitter/X URLs for better scraping
 * Since Twitter/X removed meta tags, we'll extract basic info from URL
 */
function convertTwitterUrl(url: string): string {
  // For now, we'll handle Twitter URLs specially in the scraping function
  // since proxy services seem to be down
  return url;
}

/**
 * Scrapes metadata and content from a URL without using AI
 * This is a free operation that happens immediately on content upload
 */
export async function scrapeUrl(url: string): Promise<ScrapedContent> {
  try {
    const urlType = detectUrlType(url);

    // Convert Twitter/X URLs to use FxTwitter proxy for better meta tags
    let scrapingUrl = url;
    if (urlType === 'twitter') {
      scrapingUrl = convertTwitterUrl(url);
      console.log('Converting Twitter URL for scraping:', url, '->', scrapingUrl);
    }

    const html = await fetchUrl(scrapingUrl);

    // Handle different URL types
    if (urlType === 'linkedin') {
      return await scrapeLinkedIn(url, html);
    }

    if (urlType === 'twitter') {
      return await scrapeTwitterFromFxTwitter(url, html);
    }

    // Extract title
    let title =
      extractMetaContent(html, 'og:title') ||
      extractMetaContent(html, 'twitter:title', 'name') ||
      extractText(html, 'title') ||
      'Untitled';

    // Clean and truncate title
    title = title.trim().substring(0, 200);

    // Extract description
    const description =
      extractMetaContent(html, 'og:description') ||
      extractMetaContent(html, 'twitter:description', 'name') ||
      extractMetaContent(html, 'description', 'name') ||
      '';

    // Extract paragraphs - simple approach
    const paragraphMatches = html.match(/<p[^>]*>([\s\S]*?)<\/p>/gi) || [];
    const paragraphs: string[] = [];

    for (const p of paragraphMatches) {
      const text = p.replace(/<[^>]+>/g, '').trim();
      if (text.length > 50) {
        paragraphs.push(text);
      }
    }

    let content = paragraphs.join('\n\n');

    // Limit to first 500 words
    const words = content.split(/\s+/);
    if (words.length > 500) {
      content = words.slice(0, 500).join(' ') + '...';
    }

    // Simple category suggestion based on domain or keywords
    const suggestedCategory = suggestCategory(url, title, description);

    return {
      title,
      description: description.substring(0, 300),
      content,
      suggestedCategory,
    };
  } catch (error) {
    console.error('Error scraping URL:', error);
    throw new Error(`Failed to scrape content from URL: ${error instanceof Error ? error.message : 'Unknown error'}`);
  }
}

/**
 * Simple category suggestion based on URL domain and keywords
 * No AI required - just pattern matching
 */
function suggestCategory(url: string, title: string, description: string): string | undefined {
  const urlLower = url.toLowerCase();
  const textLower = `${title} ${description}`.toLowerCase();

  // Domain-based categorization
  const domainCategories: Record<string, string> = {
    'techcrunch.com': 'technology',
    'wired.com': 'technology',
    'theverge.com': 'technology',
    'arstechnica.com': 'technology',
    'bloomberg.com': 'finance',
    'wsj.com': 'finance',
    'ft.com': 'finance',
    'espn.com': 'sport',
    'bbc.com/sport': 'sport',
    'linkedin.com': 'career',
    'nature.com': 'science',
    'sciencedaily.com': 'science',
    'healthline.com': 'health',
    'webmd.com': 'health',
  };

  // Check domain patterns
  for (const [domain, category] of Object.entries(domainCategories)) {
    if (urlLower.includes(domain)) {
      return category;
    }
  }

  // Keyword-based categorization
  const keywordCategories: Record<string, string[]> = {
    technology: ['tech', 'software', 'ai', 'coding', 'developer', 'programming', 'startup', 'app', 'digital'],
    finance: ['stock', 'market', 'investment', 'trading', 'finance', 'economy', 'banking', 'crypto', 'bitcoin'],
    sport: ['sport', 'football', 'basketball', 'soccer', 'tennis', 'olympics', 'athlete', 'game', 'match'],
    career: ['career', 'job', 'hiring', 'resume', 'interview', 'workplace', 'professional', 'leadership'],
    health: ['health', 'medical', 'fitness', 'wellness', 'diet', 'exercise', 'nutrition', 'mental health'],
    science: ['science', 'research', 'study', 'discovery', 'scientists', 'experiment', 'physics', 'biology'],
    business: ['business', 'company', 'startup', 'entrepreneur', 'corporate', 'ceo', 'revenue', 'profit'],
  };

  // Check keywords
  for (const [category, keywords] of Object.entries(keywordCategories)) {
    for (const keyword of keywords) {
      if (textLower.includes(keyword)) {
        return category;
      }
    }
  }

  return undefined; // No category detected
}
