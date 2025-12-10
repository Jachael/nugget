import { Handler } from 'aws-lambda';
import { getItem, updateItem, putItem, TableNames } from '../lib/dynamo';
import { Nugget, User } from '../lib/models';
import { summariseContent, summariseGroupedContent } from '../lib/llm';
import { computePriorityScore } from '../lib/priority';
import { sendNuggetsReadyNotification } from '../lib/notifications';
import { v4 as uuidv4 } from 'uuid';

interface SummariseNuggetEvent {
  userId: string;
  nuggetId?: string;
  nuggetIds?: string[];
  grouped?: boolean;
  groupedNuggetId?: string; // ID of the existing grouped nugget to update
  groupAfterSummarize?: boolean;
  groupNuggetIds?: string[];
  category?: string; // Category for the grouped nugget (from smart grouping)
}

export const handler: Handler<SummariseNuggetEvent> = async (event) => {
  try {
    const { userId, nuggetId, nuggetIds, grouped, groupedNuggetId, groupAfterSummarize, groupNuggetIds, category } = event;

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

      // Use the provided groupedNuggetId or create a new one (fallback)
      const finalGroupedNuggetId = groupedNuggetId || uuidv4();
      const now = Date.now() / 1000;
      const newPriorityScore = computePriorityScore(now, 0);

      // First, summarize each individual nugget if not already done
      // IMPORTANT: Do NOT mark them as 'ready' - keep them as 'processing' so they stay hidden
      // They will be archived after the grouped nugget is created
      console.log(`Summarizing ${nuggets.length} individual nuggets first...`);
      for (const nugget of nuggets) {
        if (!nugget.summary) {
          console.log(`Summarizing nugget: ${nugget.nuggetId}`);
          const summaryResult = await summariseContent(
            nugget.rawTitle,
            nugget.rawText,
            nugget.sourceUrl
          );

          // Update local copy for grouping (but DON'T update DB with 'ready' state - keep them hidden)
          nugget.rawTitle = summaryResult.title;
          nugget.summary = summaryResult.summary;
          nugget.keyPoints = summaryResult.keyPoints;
          nugget.question = summaryResult.question;
        }
      }

      // Extract individual summaries from the now-summarized nuggets
      const individualSummaries = nuggets.map(n => ({
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
        nuggetId: finalGroupedNuggetId,
        sourceUrl: nuggets[0].sourceUrl, // Primary URL
        sourceUrls: nuggets.map(n => n.sourceUrl), // All URLs
        sourceType: nuggets[0].sourceType,
        rawTitle: result.title,
        summary: result.summary,
        keyPoints: result.keyPoints,
        question: result.question,
        status: 'inbox',
        processingState: 'ready',
        category: category || nuggets[0].category, // Use passed category from smart grouping, fallback to first nugget's category
        priorityScore: newPriorityScore,
        createdAt: now,
        timesReviewed: 0,
        isGrouped: true,
        sourceNuggetIds: nuggets.map(n => n.nuggetId),
        individualSummaries, // Always include, never undefined
      };

      console.log(`Grouped nugget object:`, JSON.stringify(groupedNugget, null, 2));

      // Save/Update grouped nugget in database
      try {
        console.log(`Updating grouped nugget with ID: ${finalGroupedNuggetId}`);
        await putItem(TableNames.nuggets, groupedNugget);
        console.log(`Grouped nugget saved to database`);
      } catch (error) {
        console.error(`Failed to update grouped nugget:`, error);
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

      console.log(`Successfully created grouped nugget: ${finalGroupedNuggetId}`);

      // Send push notification that nuggets are ready
      try {
        const user = await getItem<User>(TableNames.users, { userId });
        if (user?.settings?.notificationsEnabled !== false) {
          await sendNuggetsReadyNotification(userId, 1); // 1 grouped nugget ready
          console.log(`Sent push notification to user ${userId}`);
        }
      } catch (notifError) {
        console.error('Failed to send push notification:', notifError);
        // Don't fail the whole operation for notification failure
      }

      return { success: true, groupedNuggetId: finalGroupedNuggetId };
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

    // Send push notification that nugget is ready (only for non-grouped nuggets that won't be grouped later)
    if (!groupAfterSummarize) {
      try {
        const user = await getItem<User>(TableNames.users, { userId });
        if (user?.settings?.notificationsEnabled !== false) {
          await sendNuggetsReadyNotification(userId, 1);
          console.log(`Sent push notification to user ${userId}`);
        }
      } catch (notifError) {
        console.error('Failed to send push notification:', notifError);
      }
    }

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
