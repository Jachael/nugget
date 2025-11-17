import { Handler } from 'aws-lambda';
import { getItem, updateItem, TableNames } from '../lib/dynamo';
import { Nugget } from '../lib/models';
import { summariseContent } from '../lib/llm';
import { computePriorityScore } from '../lib/priority';

interface SummariseNuggetEvent {
  userId: string;
  nuggetId: string;
}

export const handler: Handler<SummariseNuggetEvent> = async (event) => {
  try {
    const { userId, nuggetId } = event;

    if (!userId || !nuggetId) {
      console.error('Missing userId or nuggetId in event');
      return { success: false, error: 'Missing required fields' };
    }

    // Load nugget
    const nugget = await getItem<Nugget>(TableNames.nuggets, { userId, nuggetId });
    if (!nugget) {
      console.error(`Nugget not found: ${userId}/${nuggetId}`);
      return { success: false, error: 'Nugget not found' };
    }

    // Skip if already summarised
    if (nugget.summary) {
      console.log(`Nugget already summarised: ${nuggetId}`);
      return { success: true, skipped: true };
    }

    // Call LLM to summarise
    console.log(`Summarising nugget: ${nuggetId}`);
    const result = await summariseContent(
      nugget.rawTitle,
      nugget.rawText,
      nugget.sourceUrl
    );

    // Update nugget with summary and recalculate priority
    const newPriorityScore = computePriorityScore(nugget.createdAt, nugget.timesReviewed);

    await updateItem(TableNames.nuggets, { userId, nuggetId }, {
      summary: result.summary,
      keyPoints: result.keyPoints,
      question: result.question,
      priorityScore: newPriorityScore,
    });

    console.log(`Successfully summarised nugget: ${nuggetId}`);
    return { success: true };
  } catch (error) {
    console.error('Error in summariseNugget handler:', error);
    return { success: false, error: String(error) };
  }
};
