import {
  BedrockRuntimeClient,
  InvokeModelCommand,
} from '@aws-sdk/client-bedrock-runtime';
import { LLMSummarisationResult } from './models';

const client = new BedrockRuntimeClient({ region: process.env.AWS_REGION || 'eu-west-1' });

// Using Claude 3.5 Sonnet v2 on Bedrock
const MODEL_ID = 'anthropic.claude-3-5-sonnet-20241022-v2:0';

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

  const prompt = `You are helping a user process and learn from content they've saved. Please analyze the following content and provide:

1. A concise summary (2-3 sentences) that captures the main idea
2. 3-4 key bullet points highlighting the most important takeaways
3. One thoughtful reflection question that encourages deeper thinking about the content

Content to analyze:
${content}

Please respond in JSON format with the following structure:
{
  "summary": "Your 2-3 sentence summary here",
  "keyPoints": ["Point 1", "Point 2", "Point 3"],
  "question": "Your reflection question here?"
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
    const textContent = responseBody.content[0].text;

    // Parse the JSON from the response
    const result = JSON.parse(textContent);

    // Validate the response structure
    if (!result.summary || !Array.isArray(result.keyPoints) || !result.question) {
      throw new Error('Invalid response structure from LLM');
    }

    return {
      summary: result.summary,
      keyPoints: result.keyPoints,
      question: result.question,
    };
  } catch (error) {
    console.error('Error calling Bedrock:', error);

    // Return a fallback response if LLM fails
    return {
      summary: title || 'Content saved for later review',
      keyPoints: ['Review this content when you have time'],
      question: 'What can you learn from this?',
    };
  }
}
