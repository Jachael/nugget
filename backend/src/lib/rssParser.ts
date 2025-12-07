import Parser from 'rss-parser';
import { FeedItem, ParsedFeed, RecapNugget } from './models';
import { summarizeFeedItems } from './llm';

const parser = new Parser({
  timeout: 10000,
  headers: {
    'User-Agent': 'Nugget RSS Reader/1.0'
  }
});

/**
 * Parse an RSS feed and return normalized feed items
 */
export async function parseFeed(feedUrl: string, feedId: string, feedName: string): Promise<ParsedFeed> {
  try {
    const feed = await parser.parseURL(feedUrl);

    const items: FeedItem[] = feed.items.map(item => ({
      title: item.title || 'Untitled',
      link: item.link || '',
      pubDate: item.pubDate,
      content: item.content,
      contentSnippet: item.contentSnippet,
      creator: item.creator,
      categories: item.categories,
      isoDate: item.isoDate,
      guid: item.guid
    }));

    return {
      feedId,
      feedName,
      items,
      fetchedAt: Date.now() / 1000
    };
  } catch (error) {
    console.error(`Error parsing RSS feed ${feedId} (${feedUrl}):`, error);
    throw new Error(`Failed to parse RSS feed: ${error instanceof Error ? error.message : 'Unknown error'}`);
  }
}

/**
 * Get the latest N items from a feed
 */
export async function getLatestItems(feedUrl: string, feedId: string, feedName: string, limit: number = 10): Promise<FeedItem[]> {
  const parsedFeed = await parseFeed(feedUrl, feedId, feedName);
  return parsedFeed.items.slice(0, limit);
}

/**
 * Create a recap nugget from multiple feed items
 * This uses AI to summarize the latest articles into a single digestible nugget
 */
export async function createRecapNugget(
  feedItems: FeedItem[],
  feedId: string,
  feedName: string
): Promise<RecapNugget> {
  if (feedItems.length === 0) {
    throw new Error('No feed items to create recap from');
  }

  // Take top 5-10 items for the recap
  const itemsToSummarize = feedItems.slice(0, Math.min(10, feedItems.length));

  // Format articles for AI summarization
  const articles = itemsToSummarize.map(item => ({
    title: item.title,
    link: item.link,
    snippet: item.contentSnippet || item.content?.substring(0, 200) || 'No description available'
  }));

  // Use AI to create a summary of these articles
  const summary = await summarizeFeedItems(articles, feedName);

  return {
    feedId,
    feedName,
    articles,
    summary: summary.summary,
    keyPoints: summary.keyPoints,
    createdAt: Date.now() / 1000
  };
}

/**
 * Batch parse multiple feeds
 */
export async function parseMultipleFeeds(
  feeds: Array<{ url: string; id: string; name: string }>
): Promise<ParsedFeed[]> {
  const results = await Promise.allSettled(
    feeds.map(feed => parseFeed(feed.url, feed.id, feed.name))
  );

  const parsedFeeds: ParsedFeed[] = [];

  results.forEach((result, index) => {
    if (result.status === 'fulfilled') {
      parsedFeeds.push(result.value);
    } else {
      console.error(`Failed to parse feed ${feeds[index].id}:`, result.reason);
    }
  });

  return parsedFeeds;
}

/**
 * Check if a feed URL is valid and accessible
 */
export async function validateFeedUrl(feedUrl: string): Promise<boolean> {
  try {
    await parser.parseURL(feedUrl);
    return true;
  } catch (error) {
    console.error('Feed validation failed:', error);
    return false;
  }
}
