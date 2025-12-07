export interface RSSFeed {
  id: string;
  name: string;
  url: string;
  category: string;
  description: string;
  isPremium: boolean; // If true, requires Pro subscription
}

export const RSS_CATALOG: RSSFeed[] = [
  // Technology
  {
    id: 'hacker-news',
    name: 'Hacker News',
    url: 'https://hnrss.org/frontpage',
    category: 'technology',
    description: 'Top stories from the Hacker News community',
    isPremium: false
  },
  {
    id: 'techcrunch',
    name: 'TechCrunch',
    url: 'https://techcrunch.com/feed/',
    category: 'technology',
    description: 'Latest technology news and startup coverage',
    isPremium: false
  },
  {
    id: 'wired',
    name: 'Wired',
    url: 'https://www.wired.com/feed/rss',
    category: 'technology',
    description: 'Technology, science, and culture news',
    isPremium: false
  },
  {
    id: 'arstechnica',
    name: 'Ars Technica',
    url: 'https://feeds.arstechnica.com/arstechnica/features',
    category: 'technology',
    description: 'In-depth technology analysis and reviews',
    isPremium: false
  },
  {
    id: 'verge',
    name: 'The Verge',
    url: 'https://www.theverge.com/rss/index.xml',
    category: 'technology',
    description: 'Technology, science, art, and culture',
    isPremium: false
  },

  // Science
  {
    id: 'bbc-science',
    name: 'BBC Science',
    url: 'http://feeds.bbci.co.uk/news/science_and_environment/rss.xml',
    category: 'science',
    description: 'Science and environment news from BBC',
    isPremium: false
  },
  {
    id: 'scientific-american',
    name: 'Scientific American',
    url: 'http://rss.sciam.com/ScientificAmerican-Global',
    category: 'science',
    description: 'Latest developments in science and technology',
    isPremium: false
  },
  {
    id: 'nature-news',
    name: 'Nature News',
    url: 'https://www.nature.com/nature.rss',
    category: 'science',
    description: 'Breaking news from the world of science',
    isPremium: true
  },

  // Culture & News
  {
    id: 'atlantic',
    name: 'The Atlantic',
    url: 'https://www.theatlantic.com/feed/all/',
    category: 'culture',
    description: 'Politics, culture, and ideas',
    isPremium: false
  },
  {
    id: 'newyorker',
    name: 'The New Yorker',
    url: 'https://www.newyorker.com/feed/everything',
    category: 'culture',
    description: 'Culture, politics, and commentary',
    isPremium: true
  },
  {
    id: 'economist',
    name: 'The Economist',
    url: 'https://www.economist.com/the-world-this-week/rss.xml',
    category: 'business',
    description: 'Global news and business analysis',
    isPremium: true
  },

  // Business & Finance
  {
    id: 'wsj-business',
    name: 'Wall Street Journal',
    url: 'https://feeds.a.dj.com/rss/WSJcomUSBusiness.xml',
    category: 'finance',
    description: 'Business and financial news',
    isPremium: true
  },
  {
    id: 'financial-times',
    name: 'Financial Times',
    url: 'https://www.ft.com/?format=rss',
    category: 'finance',
    description: 'Global business and financial news',
    isPremium: true
  },
  {
    id: 'bloomberg',
    name: 'Bloomberg',
    url: 'https://www.bloomberg.com/feed/podcast/etf-iq.xml',
    category: 'finance',
    description: 'Markets, finance, and business news',
    isPremium: true
  },

  // Career & Professional Development
  {
    id: 'harvard-business',
    name: 'Harvard Business Review',
    url: 'https://feeds.hbr.org/harvardbusiness',
    category: 'career',
    description: 'Management insights and career advice',
    isPremium: true
  },
  {
    id: 'mit-technology',
    name: 'MIT Technology Review',
    url: 'https://www.technologyreview.com/feed/',
    category: 'technology',
    description: 'Emerging technology and innovation',
    isPremium: false
  },

  // Health & Wellness
  {
    id: 'health-harvard',
    name: 'Harvard Health',
    url: 'https://www.health.harvard.edu/blog/feed',
    category: 'health',
    description: 'Health news and medical advice',
    isPremium: true
  },

  // Entertainment & Sport
  {
    id: 'espn',
    name: 'ESPN',
    url: 'https://www.espn.com/espn/rss/news',
    category: 'sport',
    description: 'Sports news and updates',
    isPremium: false
  },
  {
    id: 'bbc-sport',
    name: 'BBC Sport',
    url: 'http://feeds.bbci.co.uk/sport/rss.xml',
    category: 'sport',
    description: 'Global sports coverage from BBC',
    isPremium: false
  }
];

/**
 * Get all feeds in the catalog
 */
export function getAllFeeds(): RSSFeed[] {
  return RSS_CATALOG;
}

/**
 * Get feeds by category
 */
export function getFeedsByCategory(category: string): RSSFeed[] {
  return RSS_CATALOG.filter(feed => feed.category === category);
}

/**
 * Get a specific feed by ID
 */
export function getFeedById(feedId: string): RSSFeed | undefined {
  return RSS_CATALOG.find(feed => feed.id === feedId);
}

/**
 * Get all available categories
 */
export function getCategories(): string[] {
  const categories = new Set(RSS_CATALOG.map(feed => feed.category));
  return Array.from(categories).sort();
}

/**
 * Get free feeds only
 */
export function getFreeFeeds(): RSSFeed[] {
  return RSS_CATALOG.filter(feed => !feed.isPremium);
}

/**
 * Get premium feeds only
 */
export function getPremiumFeeds(): RSSFeed[] {
  return RSS_CATALOG.filter(feed => feed.isPremium);
}
