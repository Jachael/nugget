import { Handler } from 'aws-lambda';
import { getItem, updateItem, putItem, TableNames } from '../lib/dynamo';
import { Nugget } from '../lib/models';
import { summariseContent, summariseGroupedContent } from '../lib/llm';
import { computePriorityScore } from '../lib/priority';
import { v4 as uuidv4 } from 'uuid';

interface SummariseNuggetEvent {
  userId: string;
  nuggetId?: string;
  nuggetIds?: string[];
  grouped?: boolean;
  groupAfterSummarize?: boolean;
  groupNuggetIds?: string[];
}

export const handler: Handler<SummariseNuggetEvent> = async (event) => {
  try {
    const { userId, nuggetId, nuggetIds, grouped, groupAfterSummarize, groupNuggetIds } = event;

    if (!userId || (!nuggetId && !nuggetIds)) {
      console.error('Missing userId or nuggetId/nuggetIds in event');
      return { success: false, error: 'Missing required fields' };
    }

    // Handle grouped nugget processing
    if (grouped && nuggetIds && nuggetIds.length > 1) {
      console.log(`Processing ${nuggetIds.length} nuggets as a group`);

      // Load all nuggets
      const nuggetPromises = nuggetIds.map(id =>
        getItem<Nugget>(TableNames.nuggets, { userId, nuggetId: id })
      );
      const nuggets = (await Promise.all(nuggetPromises)).filter((n): n is Nugget => n !== null);

      if (nuggets.length === 0) {
        console.error('No valid nuggets found for grouping');
        return { success: false, error: 'No valid nuggets found' };
      }

      // Prepare articles for grouped summarization
      const articles = nuggets.map(n => ({
        title: n.rawTitle,
        text: n.rawText,
        url: n.sourceUrl,
      }));

      // Call LLM to summarize grouped content
      console.log(`Summarising ${articles.length} articles as a group`);
      const result = await summariseGroupedContent(articles);

      // Create a new grouped nugget
      const now = Date.now() / 1000;
      const groupedNuggetId = uuidv4();
      const newPriorityScore = computePriorityScore(now, 0);

      // Extract individual summaries from original nuggets
      const individualSummaries = nuggets
        .filter(n => n.summary) // Only include nuggets that have been summarized
        .map(n => ({
          nuggetId: n.nuggetId,
          title: n.rawTitle || 'Untitled',
          summary: n.summary || '',
          keyPoints: n.keyPoints || [],
          sourceUrl: n.sourceUrl,
        }));

      console.log(`Individual summaries count: ${individualSummaries.length}`);
      console.log(`Individual summaries:`, JSON.stringify(individualSummaries, null, 2));

      const groupedNugget: Nugget = {
        userId,
        nuggetId: groupedNuggetId,
        sourceUrl: nuggets[0].sourceUrl, // Primary URL
        sourceUrls: nuggets.map(n => n.sourceUrl), // All URLs
        sourceType: nuggets[0].sourceType,
        rawTitle: result.title,
        summary: result.summary,
        keyPoints: result.keyPoints,
        question: result.question,
        status: 'inbox',
        processingState: 'ready',
        category: nuggets[0].category,
        priorityScore: newPriorityScore,
        createdAt: now,
        timesReviewed: 0,
        isGrouped: true,
        sourceNuggetIds: nuggets.map(n => n.nuggetId),
        individualSummaries, // Always include, never undefined
      };

      console.log(`Grouped nugget object:`, JSON.stringify(groupedNugget, null, 2));

      // Save grouped nugget to database
      try {
        console.log(`Creating grouped nugget with ID: ${groupedNuggetId}`);
        await putItem(TableNames.nuggets, groupedNugget);
        console.log(`Grouped nugget saved to database`);
      } catch (error) {
        console.error(`Failed to create grouped nugget:`, error);
        throw error;
      }

      // Archive the original nuggets to avoid duplication
      try {
        console.log(`Archiving ${nuggets.length} source nuggets...`);
        for (const n of nuggets) {
          console.log(`Archiving nugget: ${n.nuggetId}`);
          await updateItem(TableNames.nuggets, { userId, nuggetId: n.nuggetId }, {
            status: 'archived',
          });
          console.log(`Successfully archived: ${n.nuggetId}`);
        }
        console.log(`All source nuggets archived successfully`);
      } catch (error) {
        console.error(`Failed to archive source nuggets:`, error);
        // Continue anyway - grouped nugget is created
      }

      console.log(`Successfully created grouped nugget: ${groupedNuggetId}`);
      return { success: true, groupedNuggetId };
    }

    // Handle single nugget processing (original behavior)
    const singleNuggetId = nuggetId || nuggetIds?.[0];
    if (!singleNuggetId) {
      return { success: false, error: 'No nugget ID provided' };
    }

    // Load nugget
    const nugget = await getItem<Nugget>(TableNames.nuggets, { userId, nuggetId: singleNuggetId });
    if (!nugget) {
      console.error(`Nugget not found: ${userId}/${singleNuggetId}`);
      return { success: false, error: 'Nugget not found' };
    }

    // Skip if already summarised
    if (nugget.processingState === 'ready' && nugget.summary) {
      console.log(`Nugget already summarised: ${singleNuggetId}`);
      return { success: true, skipped: true };
    }

    // Mark as processing
    await updateItem(TableNames.nuggets, { userId, nuggetId: singleNuggetId }, {
      processingState: 'processing',
    });

    // Call LLM to summarise
    console.log(`Summarising nugget: ${singleNuggetId}`);
    const result = await summariseContent(
      nugget.rawTitle,
      nugget.rawText,
      nugget.sourceUrl
    );

    // Update nugget with summary and mark as ready
    const newPriorityScore = computePriorityScore(nugget.createdAt, nugget.timesReviewed);

    await updateItem(TableNames.nuggets, { userId, nuggetId: singleNuggetId }, {
      rawTitle: result.title,
      summary: result.summary,
      keyPoints: result.keyPoints,
      question: result.question,
      priorityScore: newPriorityScore,
      processingState: 'ready', // Mark as ready after AI processing
    });

    console.log(`Successfully summarised nugget: ${singleNuggetId}`);

    // Check if we need to trigger grouping after this summarization
    if (groupAfterSummarize && groupNuggetIds && groupNuggetIds.length > 1) {
      console.log(`Checking if all nuggets in group are ready for grouping...`);

      // Load all nuggets in the group to check if they're all summarized
      const groupNuggetPromises = groupNuggetIds.map(id =>
        getItem<Nugget>(TableNames.nuggets, { userId, nuggetId: id })
      );
      const groupNuggets = (await Promise.all(groupNuggetPromises)).filter((n): n is Nugget => n !== null);

      // Check if all nuggets are now ready (have summaries)
      const allReady = groupNuggets.every(n => n.processingState === 'ready' && n.summary);

      if (allReady) {
        console.log(`All ${groupNuggets.length} nuggets are ready! Triggering grouping...`);

        // Trigger grouping as async event
        const { LambdaClient, InvokeCommand } = await import('@aws-sdk/client-lambda');
        const lambda = new LambdaClient({ region: process.env.AWS_REGION || 'eu-west-1' });

        await lambda.send(new InvokeCommand({
          FunctionName: `nugget-${process.env.STAGE || 'dev'}-summariseNugget`,
          InvocationType: 'Event',
          Payload: Buffer.from(JSON.stringify({
            userId,
            nuggetIds: groupNuggetIds,
            grouped: true
          })),
        }));

        console.log(`Grouping triggered for ${groupNuggetIds.length} nuggets`);
      } else {
        console.log(`Not all nuggets ready yet. Waiting for others to complete.`);
      }
    }

    return { success: true };
  } catch (error) {
    console.error('Error in summariseNugget handler:', error);
    return { success: false, error: String(error) };
  }
};
