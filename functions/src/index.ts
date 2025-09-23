/**
 * Triggers the Cloud Run crawler service with the specified parameters.
 *
 * @param params - The parameters required to trigger the Cloud Run crawler.
 * @returns A promise that resolves to an object containing the job ID.
 * @throws Will throw an error if the Cloud Run request fails.
 */
/**
 * ZenRadar Cloud Functions for Matcha Monitoring
 * Handles crawl requests, notifications, and subscription payments
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

// Export payment functions
export {
  createCheckoutSession,
  createCustomerPortalSession,
  handleStripeWebhook,
  getUserSubscriptionStatus,
} from "./payments";

/**
 * Triggered when a new crawl request is created in Firestore
 * Processes the request and triggers the Cloud Run crawler(s)
 * Now supports distributed crawling across multiple instances
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

      const sitesToCrawl = crawlRequest.sites || [];
      
      // If specific sites are requested and count > 3, distribute across multiple instances
      if (sitesToCrawl.length > 3) {
        logger.info("Large crawl request, using distributed crawling", {
          requestId: event.params.requestId,
          siteCount: sitesToCrawl.length
        });
        
        // Split sites into chunks for parallel processing
        const chunkSize = 3;
        const siteChunks = [];
        for (let i = 0; i < sitesToCrawl.length; i += chunkSize) {
          siteChunks.push(sitesToCrawl.slice(i, i + chunkSize));
        }
        
        // Create sub-requests for each chunk
        const subRequestPromises = siteChunks.map(async (chunk, index) => {
          const subRequestId = `${event.params.requestId}_chunk_${index}`;
          
          return triggerCloudRunCrawler({
            requestId: subRequestId,
            triggerType: crawlRequest.triggerType || "manual",
            sites: chunk,
            userId: crawlRequest.userId,
            parentRequestId: event.params.requestId
          });
        });
        
        // Trigger all chunks in parallel
        const results = await Promise.allSettled(subRequestPromises);
        
        // Collect job IDs
        const jobIds = results
          .filter(r => r.status === 'fulfilled')
          .map(r => (r as any).value.jobId);
        
        // Update request with distributed job info
        await event.data?.ref.update({
          status: "running",
          cloudRunJobIds: jobIds,
          distributedCrawl: true,
          chunkCount: siteChunks.length,
          startedAt: new Date(),
        });
        
        logger.info("Distributed crawling triggered successfully", {
          requestId: event.params.requestId,
          chunkCount: siteChunks.length,
          jobIds
        });
        
      } else {
        // Standard single-instance crawling for smaller requests
        const result = await triggerCloudRunCrawler({
          requestId: event.params.requestId,
          triggerType: crawlRequest.triggerType || "manual",
          sites: sitesToCrawl,
          userId: crawlRequest.userId,
        });

        // Update request with Cloud Run job info
        await event.data?.ref.update({
          status: "running",
          cloudRunJobId: result.jobId,
          distributedCrawl: false,
          startedAt: new Date(),
        });

        logger.info("Single-instance crawling triggered successfully", {
          requestId: event.params.requestId,
          jobId: result.jobId,
        });
      }

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
 * Function triggered when a product's stock status changes
 * Sends push notifications to users who have favorited the product
 */
export const sendStockChangeNotification = onDocumentCreated(
  "stock_history/{historyId}",
  async (event) => {
    const stockChange = event.data?.data();
    if (!stockChange) {
      logger.error("No stock change data found");
      return;
    }

    // Only send notifications for products coming back in stock
    if (!stockChange.isInStock) {
      return;
    }

    try {
      logger.info("Processing stock change notification", {
        productId: stockChange.productId,
        productName: stockChange.productName,
        site: stockChange.site,
      });

      // Get all users who have favorited this product
      const favoritesQuery = await db.collection("user_favorites")
        .where("productId", "==", stockChange.productId)
        .get();

      if (favoritesQuery.empty) {
        logger.info("No users have favorited this product", {
          productId: stockChange.productId,
        });
        return;
      }

      // Get FCM tokens for all users who favorited this product
      const userIds = favoritesQuery.docs.map((doc) => doc.data().userId);
      const tokenPromises = userIds.map((userId) =>
        db.collection("fcm_tokens").doc(userId).get()
      );

      const tokenDocs = await Promise.all(tokenPromises);
      const validTokens = tokenDocs
        .filter((doc) => doc.exists && doc.data()?.isActive)
        .map((doc) => doc.data()?.token)
        .filter((token) => token);

      if (validTokens.length === 0) {
        logger.info("No valid FCM tokens found for favorited product", {
          productId: stockChange.productId,
        });
        return;
      }

      // Send push notification using FCM Admin SDK
      const {getMessaging} = await import("firebase-admin/messaging");
      const messaging = getMessaging();

      const message = {
        notification: {
          title: "🎉 Back in Stock!",
          body: `${stockChange.productName} is now available at ` +
            `${stockChange.site}`,
          imageUrl: stockChange.imageUrl || undefined,
        },
        data: {
          type: "stock_change",
          productId: stockChange.productId,
          productName: stockChange.productName,
          site: stockChange.site,
          url: stockChange.url || "",
        },
        tokens: validTokens,
      };

      const response = await messaging.sendEachForMulticast(message);

      logger.info("Stock change notifications sent", {
        productId: stockChange.productId,
        successCount: response.successCount,
        failureCount: response.failureCount,
        totalTokens: validTokens.length,
      });

      // Handle failed tokens (remove invalid ones)
      if (response.failureCount > 0) {
        const failedTokens: string[] = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            failedTokens.push(validTokens[idx]);
            logger.warn("Failed to send notification", {
              token: validTokens[idx].substring(0, 20) + "...",
              error: resp.error?.message,
            });
          }
        });

        // Remove invalid tokens
        await Promise.all(
          failedTokens.map(async (token) => {
            const tokenQuery = await db.collection("fcm_tokens")
              .where("token", "==", token)
              .get();

            const batch = db.batch();
            tokenQuery.docs.forEach((doc) => {
              batch.update(doc.ref, {isActive: false});
            });
            await batch.commit();
          })
        );
      }

    } catch (error) {
      logger.error("Error sending stock change notification", {
        error: error instanceof Error ? error.message : "Unknown error",
        stack: error instanceof Error ? error.stack : undefined,
        productId: stockChange.productId,
      });
    }
  }
);

/**
 * HTTP endpoint for FCM token registration
 */
export const registerFCMToken = onRequest(
  {cors: true},
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method not allowed");
      return;
    }

    try {
      const {token, userId, platform, appVersion} = req.body;

      if (!token || !userId) {
        res.status(400).json({
          error: "token and userId are required",
        });
        return;
      }

      // Store/update FCM token in Firestore
      const userTokenRef = db.collection("fcm_tokens").doc(userId);
      
      await userTokenRef.set({
        token: token,
        platform: platform || "unknown",
        appVersion: appVersion || "unknown",
        lastUpdated: new Date(),
        createdAt: new Date(),
        isActive: true,
      }, {merge: true});

      // Also update user document with latest token
      const userRef = db.collection("users").doc(userId);
      await userRef.set({
        fcmToken: token,
        lastTokenUpdate: new Date(),
      }, {merge: true});

      logger.info("FCM token registered successfully", {
        userId: userId,
        platform: platform,
        tokenPreview: token.substring(0, 20) + "...",
      });

      res.status(200).json({
        success: true,
        message: "FCM token registered successfully",
      });
    } catch (error) {
      logger.error("Error registering FCM token", {
        error: error instanceof Error ? error.message : "Unknown error",
        stack: error instanceof Error ? error.stack : undefined,
      });

      res.status(500).json({
        error: "Failed to register FCM token",
        details: error instanceof Error ? error.message : "Unknown error",
      });
    }
  }
);

/**
 * HTTP endpoint for updating user favorites and FCM subscriptions
 */
export const updateUserFavorites = onRequest(
  {cors: true},
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method not allowed");
      return;
    }

    try {
      const {userId, productId, isFavorite} = req.body;

      if (!userId || !productId || typeof isFavorite !== "boolean") {
        res.status(400).json({
          error: "userId, productId, and isFavorite are required",
        });
        return;
      }

      const favoriteRef = db.collection("user_favorites").doc(`${userId}_${productId}`);

      if (isFavorite) {
        // Add favorite
        await favoriteRef.set({
          userId: userId,
          productId: productId,
          createdAt: new Date(),
          isActive: true,
        });

        logger.info("User favorite added", {
          userId: userId,
          productId: productId,
        });
      } else {
        // Remove favorite
        await favoriteRef.delete();

        logger.info("User favorite removed", {
          userId: userId,
          productId: productId,
        });
      }

      res.status(200).json({
        success: true,
        message: `Favorite ${isFavorite ? "added" : "removed"} successfully`,
      });
    } catch (error) {
      logger.error("Error updating user favorites", {
        error: error instanceof Error ? error.message : "Unknown error",
        stack: error instanceof Error ? error.stack : undefined,
      });      res.status(500).json({
        error: "Failed to update user favorites",
        details: error instanceof Error ? error.message : "Unknown error",
      });
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
  parentRequestId?: string;
}): Promise<{jobId: string}> {
  // TODO: Replace with your actual Cloud Run service URL
  const cloudRunUrl = process.env.CLOUD_RUN_CRAWLER_URL ||
    "https://zenradar-crawler-989787576521.europe-west3.run.app";

  const payload = {
    requestId: params.requestId,
    triggerType: params.triggerType,
    sites: params.sites,
    userId: params.userId,
    parentRequestId: params.parentRequestId,
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
