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
  {
    id: 'mit-technology',
    name: 'MIT Technology Review',
    url: 'https://www.technologyreview.com/feed/',
    category: 'technology',
    description: 'Emerging technology and innovation',
    isPremium: false
  },
  {
    id: 'engadget',
    name: 'Engadget',
    url: 'https://www.engadget.com/rss.xml',
    category: 'technology',
    description: 'Technology news and gadget reviews',
    isPremium: false
  },
  {
    id: 'macrumors',
    name: 'MacRumors',
    url: 'https://feeds.macrumors.com/MacRumors-All',
    category: 'technology',
    description: 'Apple news and rumors',
    isPremium: false
  },
  {
    id: '9to5mac',
    name: '9to5Mac',
    url: 'https://9to5mac.com/feed/',
    category: 'technology',
    description: 'Apple news and insights',
    isPremium: false
  },
  {
    id: 'android-central',
    name: 'Android Central',
    url: 'https://www.androidcentral.com/feed',
    category: 'technology',
    description: 'Android news and reviews',
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
  {
    id: 'science-daily',
    name: 'Science Daily',
    url: 'https://www.sciencedaily.com/rss/all.xml',
    category: 'science',
    description: 'Latest research and discoveries',
    isPremium: false
  },
  {
    id: 'new-scientist',
    name: 'New Scientist',
    url: 'https://www.newscientist.com/feed/home/',
    category: 'science',
    description: 'Science and technology news',
    isPremium: true
  },
  {
    id: 'phys-org',
    name: 'Phys.org',
    url: 'https://phys.org/rss-feed/',
    category: 'science',
    description: 'Science, research, and technology news',
    isPremium: false
  },

  // News
  {
    id: 'bbc-news',
    name: 'BBC News',
    url: 'http://feeds.bbci.co.uk/news/rss.xml',
    category: 'news',
    description: 'Breaking news from around the world',
    isPremium: false
  },
  {
    id: 'reuters',
    name: 'Reuters',
    url: 'https://www.reutersagency.com/feed/',
    category: 'news',
    description: 'International news and wire service',
    isPremium: false
  },
  {
    id: 'ap-news',
    name: 'AP News',
    url: 'https://apnews.com/hub/wire-service/index.rss',
    category: 'news',
    description: 'Breaking news from Associated Press',
    isPremium: false
  },
  {
    id: 'npr',
    name: 'NPR',
    url: 'https://feeds.npr.org/1001/rss.xml',
    category: 'news',
    description: 'National Public Radio news',
    isPremium: false
  },
  {
    id: 'guardian',
    name: 'The Guardian',
    url: 'https://www.theguardian.com/world/rss',
    category: 'news',
    description: 'World news and analysis',
    isPremium: false
  },
  {
    id: 'nytimes',
    name: 'New York Times',
    url: 'https://rss.nytimes.com/services/xml/rss/nyt/HomePage.xml',
    category: 'news',
    description: 'Breaking news and top stories',
    isPremium: true
  },

  // Culture & Politics
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
    id: 'vox',
    name: 'Vox',
    url: 'https://www.vox.com/rss/index.xml',
    category: 'culture',
    description: 'Explainers and news analysis',
    isPremium: false
  },
  {
    id: 'slate',
    name: 'Slate',
    url: 'https://slate.com/feeds/all.rss',
    category: 'culture',
    description: 'News, politics, and culture',
    isPremium: false
  },

  // Business & Finance
  {
    id: 'economist',
    name: 'The Economist',
    url: 'https://www.economist.com/the-world-this-week/rss.xml',
    category: 'business',
    description: 'Global news and business analysis',
    isPremium: true
  },
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
  {
    id: 'forbes',
    name: 'Forbes',
    url: 'https://www.forbes.com/real-time/feed2/',
    category: 'business',
    description: 'Business and entrepreneurship news',
    isPremium: false
  },
  {
    id: 'cnbc',
    name: 'CNBC',
    url: 'https://www.cnbc.com/id/100003114/device/rss/rss.html',
    category: 'finance',
    description: 'Business and financial markets',
    isPremium: false
  },
  {
    id: 'marketwatch',
    name: 'MarketWatch',
    url: 'http://feeds.marketwatch.com/marketwatch/topstories/',
    category: 'finance',
    description: 'Stock market and financial news',
    isPremium: false
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
    id: 'fastcompany',
    name: 'Fast Company',
    url: 'https://www.fastcompany.com/latest/rss',
    category: 'career',
    description: 'Innovation and business ideas',
    isPremium: false
  },
  {
    id: 'inc',
    name: 'Inc.',
    url: 'https://www.inc.com/rss/',
    category: 'career',
    description: 'Startup and small business news',
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
  {
    id: 'webmd',
    name: 'WebMD',
    url: 'https://rssfeeds.webmd.com/rss/rss.aspx?RSSSource=RSS_PUBLIC',
    category: 'health',
    description: 'Health information and medical news',
    isPremium: false
  },
  {
    id: 'medical-news-today',
    name: 'Medical News Today',
    url: 'https://www.medicalnewstoday.com/newsfeeds/rss/all',
    category: 'health',
    description: 'Latest health and medical research',
    isPremium: false
  },
  {
    id: 'healthline',
    name: 'Healthline',
    url: 'https://www.healthline.com/rss',
    category: 'health',
    description: 'Health information and wellness',
    isPremium: false
  },

  // Sports
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
  },
  {
    id: 'bleacher-report',
    name: 'Bleacher Report',
    url: 'https://bleacherreport.com/articles/feed',
    category: 'sport',
    description: 'Sports news and highlights',
    isPremium: false
  },
  {
    id: 'espn-nba',
    name: 'ESPN NBA',
    url: 'https://www.espn.com/espn/rss/nba/news',
    category: 'sport',
    description: 'NBA news and updates',
    isPremium: false
  },
  {
    id: 'espn-nfl',
    name: 'ESPN NFL',
    url: 'https://www.espn.com/espn/rss/nfl/news',
    category: 'sport',
    description: 'NFL news and updates',
    isPremium: false
  },
  {
    id: 'espn-soccer',
    name: 'ESPN Soccer',
    url: 'https://www.espn.com/espn/rss/soccer/news',
    category: 'sport',
    description: 'Soccer/Football news worldwide',
    isPremium: false
  },

  // Entertainment
  {
    id: 'variety',
    name: 'Variety',
    url: 'https://variety.com/feed/',
    category: 'entertainment',
    description: 'Entertainment industry news',
    isPremium: true
  },
  {
    id: 'hollywood-reporter',
    name: 'Hollywood Reporter',
    url: 'https://www.hollywoodreporter.com/feed/',
    category: 'entertainment',
    description: 'Entertainment and media news',
    isPremium: true
  },
  {
    id: 'rolling-stone',
    name: 'Rolling Stone',
    url: 'https://www.rollingstone.com/feed/',
    category: 'entertainment',
    description: 'Music, culture, and politics',
    isPremium: false
  },
  {
    id: 'ign',
    name: 'IGN',
    url: 'https://feeds.ign.com/ign/all',
    category: 'entertainment',
    description: 'Video games and entertainment',
    isPremium: false
  },
  {
    id: 'polygon',
    name: 'Polygon',
    url: 'https://www.polygon.com/rss/index.xml',
    category: 'entertainment',
    description: 'Gaming and pop culture',
    isPremium: false
  },
  {
    id: 'kotaku',
    name: 'Kotaku',
    url: 'https://kotaku.com/rss',
    category: 'entertainment',
    description: 'Gaming news and culture',
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
