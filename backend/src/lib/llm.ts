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
