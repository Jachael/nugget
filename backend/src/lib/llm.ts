import {
  BedrockRuntimeClient,
  InvokeModelCommand,
} from '@aws-sdk/client-bedrock-runtime';
import { LLMSummarisationResult } from './models';

const client = new BedrockRuntimeClient({ region: process.env.AWS_REGION || 'eu-west-1' });

// Using Claude 4.5 Sonnet (Sonnet 4.5) - latest model via EU inference profile
const MODEL_ID = 'eu.anthropic.claude-sonnet-4-5-20250929-v1:0';

interface ArticleContent {
  title: string | undefined;
  text: string | undefined;
  url: string;
}

interface FeedArticle {
  title: string;
  link: string;
  snippet: string;
}

export async function summariseGroupedContent(
  articles: ArticleContent[]
): Promise<LLMSummarisationResult> {
  if (articles.length === 0) {
    throw new Error('No articles provided to summarize');
  }

  // Build combined content from all articles
  const combinedContent = articles.map((article, index) => {
    const parts = [
      `\n--- Article ${index + 1} ---`,
      article.title ? `Title: ${article.title}` : '',
      article.text ? `Content: ${article.text}` : '',
      `URL: ${article.url}`,
    ].filter(Boolean);
    return parts.join('\n');
  }).join('\n\n');

  if (!combinedContent.trim()) {
    throw new Error('No content available to summarise');
  }

  const prompt = `Analyze these ${articles.length} related articles and extract key learning points. Synthesize the information from all articles into a cohesive summary.

${combinedContent}

Respond ONLY with valid JSON in exactly this format (no other text):
{
  "title": "Clear, concise title covering all articles (max 80 chars)",
  "summary": "2-3 sentence summary synthesizing the main ideas from all articles",
  "keyPoints": ["Key point 1", "Key point 2", "Key point 3", "Key point 4", "Key point 5"],
  "question": "Thoughtful reflection question based on all articles?"
}`;

  const payload = {
    anthropic_version: 'bedrock-2023-05-31',
    max_tokens: 1500,
    messages: [
      {
        role: 'user',
        content: prompt,
      },
    ],
  };

  try {
    const command = new InvokeModelCommand({
      modelId: MODEL_ID,
      contentType: 'application/json',
      accept: 'application/json',
      body: JSON.stringify(payload),
    });

    const response = await client.send(command);
    const responseBody = JSON.parse(new TextDecoder().decode(response.body));

    let textContent = responseBody.content[0].text;
    console.log('Claude grouped response:', textContent);

    textContent = textContent.trim();
    if (textContent.startsWith('```')) {
      textContent = textContent.replace(/^```(?:json)?\n?/, '').replace(/\n?```$/, '').trim();
    }

    const result = JSON.parse(textContent);

    if (!result.title || !result.summary || !Array.isArray(result.keyPoints) || !result.question) {
      throw new Error('Invalid response structure from LLM');
    }

    return {
      title: result.title,
      summary: result.summary,
      keyPoints: result.keyPoints,
      question: result.question,
    };
  } catch (error) {
    console.error('Error calling Bedrock for grouped summarization:', error);

    return {
      title: articles[0]?.title || 'Grouped content for review',
      summary: `${articles.length} articles saved for review`,
      keyPoints: ['Review these articles when you have time'],
      question: 'What can you learn from these articles?',
    };
  }
}

export async function summariseContent(
  title: string | undefined,
  text: string | undefined,
  url: string
): Promise<LLMSummarisationResult> {
  const content = [
    title ? `Title: ${title}` : '',
    text ? `Content: ${text}` : '',
    `URL: ${url}`,
  ].filter(Boolean).join('\n\n');

  if (!content.trim()) {
    throw new Error('No content available to summarise');
  }

  const prompt = `Analyze this content and extract key learning points.

Content:
${content}

Respond ONLY with valid JSON in exactly this format (no other text):
{
  "title": "Clear, concise title (max 80 chars)",
  "summary": "2-3 sentence summary of main idea",
  "keyPoints": ["Key point 1", "Key point 2", "Key point 3"],
  "question": "Thoughtful reflection question?"
}`;

  const payload = {
    anthropic_version: 'bedrock-2023-05-31',
    max_tokens: 1000,
    messages: [
      {
        role: 'user',
        content: prompt,
      },
    ],
  };

  try {
    const command = new InvokeModelCommand({
      modelId: MODEL_ID,
      contentType: 'application/json',
      accept: 'application/json',
      body: JSON.stringify(payload),
    });

    const response = await client.send(command);
    const responseBody = JSON.parse(new TextDecoder().decode(response.body));

    // Extract the text content from Claude's response
    let textContent = responseBody.content[0].text;
    console.log('Claude response:', textContent);

    // Strip markdown code blocks if present (```json ... ```)
    textContent = textContent.trim();
    if (textContent.startsWith('```')) {
      // Remove opening ```json or ``` and closing ```
      textContent = textContent.replace(/^```(?:json)?\n?/, '').replace(/\n?```$/, '').trim();
    }

    // Parse the JSON from the response
    const result = JSON.parse(textContent);

    // Validate the response structure
    if (!result.title || !result.summary || !Array.isArray(result.keyPoints) || !result.question) {
      throw new Error('Invalid response structure from LLM');
    }

    return {
      title: result.title,
      summary: result.summary,
      keyPoints: result.keyPoints,
      question: result.question,
    };
  } catch (error) {
    console.error('Error calling Bedrock:', error);

    // Return a fallback response if LLM fails
    return {
      title: title || 'Content saved for later review',
      summary: title || 'Content saved for later review',
      keyPoints: ['Review this content when you have time'],
      question: 'What can you learn from this?',
    };
  }
}

/**
 * Summarize multiple RSS feed items into a cohesive recap
 */
interface ScrapedArticle {
  title: string;
  link: string;
  content: string;  // Full scraped content
}

interface IndividualArticleSummary {
  title: string;
  summary: string;
  keyPoints: string[];
  sourceUrl: string;
}

interface FeedSummarisationResult extends LLMSummarisationResult {
  individualSummaries: IndividualArticleSummary[];
}

/**
 * Summarize RSS feed articles with full AI processing for each article
 * Returns overall summary + individual article summaries with key points
 */
export async function summarizeFeedWithArticles(
  articles: ScrapedArticle[],
  feedName: string
): Promise<FeedSummarisationResult> {
  if (articles.length === 0) {
    throw new Error('No articles provided to summarize');
  }

  // Format articles with full content for the prompt
  const articlesText = articles.map((article, index) => {
    // Truncate content to ~1000 chars per article to stay within token limits
    const truncatedContent = article.content.length > 1000
      ? article.content.substring(0, 1000) + '...'
      : article.content;
    return `--- Article ${index + 1} ---
Title: ${article.title}
URL: ${article.link}
Content:
${truncatedContent}`;
  }).join('\n\n');

  const prompt = `You are analyzing ${articles.length} articles from "${feedName}".

For EACH article, provide:
1. A clear, concise title (max 80 chars)
2. A 2-3 sentence summary
3. 3-5 key learning points

Also provide an overall digest summary.

Articles:
${articlesText}

Respond ONLY with valid JSON in exactly this format (no other text):
{
  "title": "Today's ${feedName} Digest",
  "summary": "2-3 sentence overview of the main themes across all articles",
  "keyPoints": ["Overall theme 1", "Overall theme 2", "Overall theme 3"],
  "question": "Thoughtful reflection question about these stories?",
  "individualSummaries": [
    {
      "title": "Clear title for article 1",
      "summary": "2-3 sentence summary of article 1",
      "keyPoints": ["Key point 1", "Key point 2", "Key point 3"],
      "sourceUrl": "${articles[0]?.link || 'url'}"
    }
  ]
}

IMPORTANT: Include an entry in individualSummaries for EACH of the ${articles.length} articles, in the same order they appear above.`;

  const payload = {
    anthropic_version: 'bedrock-2023-05-31',
    max_tokens: 4000,
    messages: [
      {
        role: 'user',
        content: prompt,
      },
    ],
  };

  try {
    const command = new InvokeModelCommand({
      modelId: MODEL_ID,
      contentType: 'application/json',
      accept: 'application/json',
      body: JSON.stringify(payload),
    });

    const response = await client.send(command);
    const responseBody = JSON.parse(new TextDecoder().decode(response.body));

    let textContent = responseBody.content[0].text;
    console.log('Claude feed with articles response:', textContent.substring(0, 500) + '...');

    textContent = textContent.trim();
    if (textContent.startsWith('```')) {
      textContent = textContent.replace(/^```(?:json)?\n?/, '').replace(/\n?```$/, '').trim();
    }

    const result = JSON.parse(textContent);

    if (!result.title || !result.summary || !Array.isArray(result.keyPoints) ||
        !result.question || !Array.isArray(result.individualSummaries)) {
      throw new Error('Invalid response structure from LLM');
    }

    // Ensure each individual summary has the correct sourceUrl from our input
    const individualSummaries = result.individualSummaries.map((summary: IndividualArticleSummary, index: number) => ({
      ...summary,
      sourceUrl: articles[index]?.link || summary.sourceUrl,
    }));

    return {
      title: result.title,
      summary: result.summary,
      keyPoints: result.keyPoints,
      question: result.question,
      individualSummaries,
    };
  } catch (error) {
    console.error('Error calling Bedrock for feed with articles summarization:', error);

    // Fallback: create basic summaries from scraped content
    const individualSummaries = articles.map(article => ({
      title: article.title,
      summary: article.content.substring(0, 200) + '...',
      keyPoints: ['Review this article for details'],
      sourceUrl: article.link,
    }));

    return {
      title: `Latest from ${feedName}`,
      summary: `${articles.length} new articles available to read`,
      keyPoints: articles.slice(0, 3).map(a => a.title),
      question: 'What insights can you gain from these stories?',
      individualSummaries,
    };
  }
}

export async function summarizeFeedItems(
  articles: FeedArticle[],
  feedName: string
): Promise<LLMSummarisationResult> {
  if (articles.length === 0) {
    throw new Error('No articles provided to summarize');
  }

  // Format articles for the prompt
  const articlesText = articles.map((article, index) => {
    return `${index + 1}. ${article.title}\n   ${article.snippet}\n   Link: ${article.link}`;
  }).join('\n\n');

  const prompt = `You are analyzing the latest articles from "${feedName}". Create a cohesive summary of the top stories.

Articles:
${articlesText}

Respond ONLY with valid JSON in exactly this format (no other text):
{
  "title": "Today's Top Stories from ${feedName}",
  "summary": "2-3 sentence summary of the main themes and most important stories",
  "keyPoints": ["Most important story or trend 1", "Important story or trend 2", "Important story or trend 3", "Important story or trend 4"],
  "question": "Thoughtful reflection question about these stories?"
}`;

  const payload = {
    anthropic_version: 'bedrock-2023-05-31',
    max_tokens: 1000,
    messages: [
      {
        role: 'user',
        content: prompt,
      },
    ],
  };

  try {
    const command = new InvokeModelCommand({
      modelId: MODEL_ID,
      contentType: 'application/json',
      accept: 'application/json',
      body: JSON.stringify(payload),
    });

    const response = await client.send(command);
    const responseBody = JSON.parse(new TextDecoder().decode(response.body));

    let textContent = responseBody.content[0].text;
    console.log('Claude feed summary response:', textContent);

    textContent = textContent.trim();
    if (textContent.startsWith('```')) {
      textContent = textContent.replace(/^```(?:json)?\n?/, '').replace(/\n?```$/, '').trim();
    }

    const result = JSON.parse(textContent);

    if (!result.title || !result.summary || !Array.isArray(result.keyPoints) || !result.question) {
      throw new Error('Invalid response structure from LLM');
    }

    return {
      title: result.title,
      summary: result.summary,
      keyPoints: result.keyPoints,
      question: result.question,
    };
  } catch (error) {
    console.error('Error calling Bedrock for feed summarization:', error);

    return {
      title: `Latest from ${feedName}`,
      summary: `${articles.length} new articles available to read`,
      keyPoints: articles.slice(0, 3).map(a => a.title),
      question: 'What insights can you gain from these stories?',
    };
  }
}
