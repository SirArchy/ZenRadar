/**
 * Triggers the Cloud Run crawler service with the specified parameters.
 *
 * @param params - The parameters required to trigger the Cloud Run crawler.
 * @returns A promise that resolves to an object containing the job ID.
 * @throws Will throw an error if the Cloud Run request fails.
 */
/**
 * ZenRadar Cloud Functions for Matcha Stock Monitoring
 * Handles crawl requests and triggers Cloud Run crawler
 */

import {setGlobalOptions} from "firebase-functions";
import {onRequest} from "firebase-functions/v2/https";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import * as logger from "firebase-functions/logger";
import {initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";

// Initialize Firebase Admin
initializeApp();
const db = getFirestore();

// For cost control, set maximum container instances
setGlobalOptions({
  maxInstances: 10,
  region: "europe-west3", // Same region as your Firestore
});

/**
 * Triggered when a new crawl request is created in Firestore
 * Processes the request and triggers the Cloud Run crawler
 */
export const processCrawlRequest = onDocumentCreated(
  "crawl_requests/{requestId}",
  async (event) => {
    const crawlRequest = event.data?.data();
    if (!crawlRequest) {
      logger.error("No crawl request data found");
      return;
    }

    logger.info("Processing crawl request",
      {requestId: event.params.requestId});

    try {
      // Update request status to processing
      await event.data?.ref.update({
        status: "processing",
        processedAt: new Date(),
      });

      // Trigger Cloud Run crawler
      const result = await triggerCloudRunCrawler({
        requestId: event.params.requestId,
        triggerType: crawlRequest.triggerType || "manual",
        sites: crawlRequest.sites || [],
        userId: crawlRequest.userId,
      });

      // Update request with Cloud Run job info
      await event.data?.ref.update({
        status: "running",
        cloudRunJobId: result.jobId,
        startedAt: new Date(),
      });

      logger.info("Cloud Run crawler triggered successfully", {
        requestId: event.params.requestId,
        jobId: result.jobId,
      });
    } catch (error) {
      logger.error("Error processing crawl request", {
        requestId: event.params.requestId,
        error: error instanceof Error ? error.message : String(error),
        stack: error instanceof Error ? error.stack : undefined,
      });
      await event.data?.ref.update({
        status: "failed",
        error: error instanceof Error ? error.message : "Unknown error",
        failedAt: new Date(),
      });
    }
  }
);

/**
 * Scheduled function that triggers crawls every hour
 */
export const scheduledCrawl = onSchedule(
  {
    schedule: "0 * * * *", // Every hour at minute 0
    timeZone: "Europe/Berlin",
    retryCount: 3,
  },
  async () => {
    logger.info("Starting scheduled crawl");

    try {
      // Create a scheduled crawl request
      const crawlRequestRef = await db.collection("crawl_requests").add({
        triggerType: "scheduled",
        sites: [], // Empty means all enabled sites
        createdAt: new Date(),
        status: "pending",
        userId: "system",
        priority: "normal",
      });

      logger.info("Scheduled crawl request created", {
        requestId: crawlRequestRef.id,
      });
    } catch (error) {
      logger.error("Error creating scheduled crawl request", {error});
      throw error;
    }
  }
);

/**
 * HTTP endpoint for manual crawl triggers from the Flutter app
 */
export const triggerManualCrawl = onRequest(
  {cors: true},
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method not allowed");
      return;
    }

    try {
      const {sites, userId} = req.body;

      if (!userId) {
        res.status(400).json({error: "userId is required"});
        return;
      }

      // Create a manual crawl request
      const crawlRequestRef = await db.collection("crawl_requests").add({
        triggerType: "manual",
        sites: sites || [],
        createdAt: new Date(),
        status: "pending",
        userId: userId,
        priority: "high",
      });

      logger.info("Manual crawl request created", {
        requestId: crawlRequestRef.id,
        userId: userId,
      });

      res.status(200).json({
        success: true,
        requestId: crawlRequestRef.id,
        message: "Crawl request created successfully",
      });
    } catch (error) {
      logger.error("Error creating manual crawl request", {error});
      res.status(500).json({
        error: "Failed to create crawl request",
        details: error instanceof Error ? error.message : "Unknown error",
      });
    }
  }
);

/**
 * Scheduled function to clean up old history data (runs weekly)
 */
export const cleanupOldHistory = onSchedule(
  {
    schedule: "0 2 * * 0", // Every Sunday at 2 AM
    timeZone: "Europe/Berlin",
    retryCount: 1,
  },
  async () => {
    logger.info("Starting cleanup of old history data");

    try {
      const cutoffDate = new Date();
      cutoffDate.setDate(cutoffDate.getDate() - 90); // Keep 90 days of history

      // Clean up old price history
      const priceHistoryQuery = db.collection("price_history")
        .where("date", "<", cutoffDate)
        .limit(1000); // Process in batches

      const priceHistorySnapshot = await priceHistoryQuery.get();
      const priceHistoryBatch = db.batch();

      priceHistorySnapshot.docs.forEach((doc) => {
        priceHistoryBatch.delete(doc.ref);
      });

      if (!priceHistorySnapshot.empty) {
        await priceHistoryBatch.commit();
        logger.info(`Deleted ${priceHistorySnapshot.size} 
        old price history entries`);
      }

      // Clean up old stock history
      const stockHistoryQuery = db.collection("stock_history")
        .where("timestamp", "<", cutoffDate)
        .limit(1000); // Process in batches

      const stockHistorySnapshot = await stockHistoryQuery.get();
      const stockHistoryBatch = db.batch();

      stockHistorySnapshot.docs.forEach((doc) => {
        stockHistoryBatch.delete(doc.ref);
      });

      if (!stockHistorySnapshot.empty) {
        await stockHistoryBatch.commit();
        logger.info(`Deleted ${stockHistorySnapshot.size} 
        old stock history entries`);
      }

      logger.info("History cleanup completed successfully");
    } catch (error) {
      logger.error("Error during history cleanup", {
        error: error instanceof Error ? error.message : String(error),
      });
      throw error;
    }
  }
);

/**
 * Function to trigger the Cloud Run crawler service
 * @param {Object} params - The parameters required
 * to trigger the Cloud Run crawler.
 */
async function triggerCloudRunCrawler(params: {
  requestId: string;
  triggerType: string;
  sites: string[];
  userId: string;
}): Promise<{jobId: string}> {
  // TODO: Replace with your actual Cloud Run service URL
  const cloudRunUrl = process.env.CLOUD_RUN_CRAWLER_URL ||
    "https://zenradar-crawler-989787576521.europe-west3.run.app";

  const payload = {
    requestId: params.requestId,
    triggerType: params.triggerType,
    sites: params.sites,
    userId: params.userId,
    timestamp: new Date().toISOString(),
  };

  try {
    logger.info("Attempting to call Cloud Run", {
      url: cloudRunUrl + "/crawl",
      requestId: params.requestId,
    });

    const response = await fetch(cloudRunUrl + "/crawl", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${await getAccessToken()}`,
      },
      body: JSON.stringify(payload),
    });

    logger.info("Cloud Run response received", {
      status: response.status,
      statusText: response.statusText,
      requestId: params.requestId,
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(
        `Cloud Run request failed: ${response.status} ` +
        `${response.statusText} - ${errorText}`
      );
    }

    const result = await response.json();
    return {jobId: result.jobId || params.requestId};
  } catch (error) {
    logger.error("Error triggering Cloud Run crawler", {
      error: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined,
      params,
      cloudRunUrl,
    });
    throw error;
  }
}

/**
 * Get access token for authenticating with Cloud Run
 */
async function getAccessToken(): Promise<string> {
  try {
    logger.info("Getting access token for Cloud Run authentication");

    const {GoogleAuth} = await import("google-auth-library");
    const auth = new GoogleAuth({
      scopes: ["https://www.googleapis.com/auth/cloud-platform"],
    });
    const client = await auth.getClient();
    const accessToken = await client.getAccessToken();

    if (!accessToken.token) {
      throw new Error("Failed to get access token - token is null");
    }

    logger.info("Access token obtained successfully");
    return accessToken.token;
  } catch (error) {
    logger.error("Error getting access token", {
      error: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined,
    });
    throw error;
  }
}
