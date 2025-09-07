/**
 * Stripe Payment Processing Functions for ZenRadar
 * Handles subscription creation, management, and premium user status
 */

import {onRequest} from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import {getFirestore} from "firebase-admin/firestore";
import {getAuth} from "firebase-admin/auth";

const db = getFirestore();

// Initialize Stripe (you'll need to add this to your environment)
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

/**
 * Create a Stripe checkout session for premium subscription
 */
export const createCheckoutSession = onRequest(
  {cors: true},
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method not allowed");
      return;
    }

    try {
      const {userId, priceId, successUrl, cancelUrl} = req.body;

      if (!userId || !priceId) {
        res.status(400).json({
          error: "userId and priceId are required",
        });
        return;
      }

      // Get or create Stripe customer
      const customer = await getOrCreateStripeCustomer(userId);

      // Create checkout session
      const session = await stripe.checkout.sessions.create({
        customer: customer.id,
        payment_method_types: ['card'],
        line_items: [{
          price: priceId,
          quantity: 1,
        }],
        mode: 'subscription',
        success_url: successUrl || 'https://yourapp.com/success',
        cancel_url: cancelUrl || 'https://yourapp.com/cancel',
        subscription_data: {
          metadata: {
            userId: userId,
            app: 'zenradar',
          },
        },
        metadata: {
          userId: userId,
        },
      });

      logger.info("Checkout session created", {
        userId: userId,
        sessionId: session.id,
        customerId: customer.id,
      });

      res.status(200).json({
        sessionId: session.id,
        sessionUrl: session.url,
      });

    } catch (error) {
      logger.error("Error creating checkout session", {
        error: error instanceof Error ? error.message : "Unknown error",
      });

      res.status(500).json({
        error: "Failed to create checkout session",
        details: error instanceof Error ? error.message : "Unknown error",
      });
    }
  }
);

/**
 * Create a Stripe customer portal session for subscription management
 */
export const createCustomerPortalSession = onRequest(
  {cors: true},
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method not allowed");
      return;
    }

    try {
      const {userId, returnUrl} = req.body;

      if (!userId) {
        res.status(400).json({
          error: "userId is required",
        });
        return;
      }

      // Get Stripe customer
      const customer = await getOrCreateStripeCustomer(userId);

      // Create portal session
      const session = await stripe.billingPortal.sessions.create({
        customer: customer.id,
        return_url: returnUrl || 'https://yourapp.com/settings',
      });

      logger.info("Customer portal session created", {
        userId: userId,
        customerId: customer.id,
      });

      res.status(200).json({
        sessionUrl: session.url,
      });

    } catch (error) {
      logger.error("Error creating customer portal session", {
        error: error instanceof Error ? error.message : "Unknown error",
      });

      res.status(500).json({
        error: "Failed to create customer portal session",
        details: error instanceof Error ? error.message : "Unknown error",
      });
    }
  }
);

/**
 * Handle Stripe webhooks to update user subscription status
 */
export const handleStripeWebhook = onRequest(
  {cors: true},
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).send("Method not allowed");
      return;
    }

    const sig = req.headers['stripe-signature'];
    const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

    if (!webhookSecret) {
      logger.error("Stripe webhook secret not configured");
      res.status(500).send("Webhook secret not configured");
      return;
    }

    let event;

    try {
      // Verify webhook signature
      event = stripe.webhooks.constructEvent(req.body, sig, webhookSecret);
    } catch (error) {
      logger.error("Webhook signature verification failed", {error});
      res.status(400).send(`Webhook signature verification failed`);
      return;
    }

    try {
      // Handle the event
      switch (event.type) {
        case 'customer.subscription.created':
          await handleSubscriptionCreated(event.data.object);
          break;
        case 'customer.subscription.updated':
          await handleSubscriptionUpdated(event.data.object);
          break;
        case 'customer.subscription.deleted':
          await handleSubscriptionDeleted(event.data.object);
          break;
        case 'invoice.payment_succeeded':
          await handlePaymentSucceeded(event.data.object);
          break;
        case 'invoice.payment_failed':
          await handlePaymentFailed(event.data.object);
          break;
        default:
          logger.info("Unhandled webhook event type", {type: event.type});
      }

      res.status(200).json({received: true});

    } catch (error) {
      logger.error("Error handling webhook", {
        error: error instanceof Error ? error.message : "Unknown error",
        eventType: event.type,
      });
      res.status(500).send("Error handling webhook");
    }
  }
);

/**
 * Get user's current subscription status
 */
export const getUserSubscriptionStatus = onRequest(
  {cors: true},
  async (req, res) => {
    if (req.method !== "GET") {
      res.status(405).send("Method not allowed");
      return;
    }

    try {
      const userId = req.query.userId as string;

      if (!userId) {
        res.status(400).json({
          error: "userId is required",
        });
        return;
      }

      // Get user subscription from Firestore
      const userDoc = await db.collection("users").doc(userId).get();
      
      if (!userDoc.exists) {
        res.status(404).json({
          error: "User not found",
        });
        return;
      }

      const userData = userDoc.data();
      const subscriptionStatus = {
        isPremium: userData?.isPremium || false,
        subscriptionTier: userData?.subscriptionTier || 'free',
        subscriptionStatus: userData?.subscriptionStatus || 'inactive',
        subscriptionId: userData?.stripeSubscriptionId || null,
        currentPeriodEnd: userData?.subscriptionCurrentPeriodEnd || null,
        customerId: userData?.stripeCustomerId || null,
      };

      res.status(200).json(subscriptionStatus);

    } catch (error) {
      logger.error("Error getting subscription status", {
        error: error instanceof Error ? error.message : "Unknown error",
      });

      res.status(500).json({
        error: "Failed to get subscription status",
        details: error instanceof Error ? error.message : "Unknown error",
      });
    }
  }
);

// Helper Functions

/**
 * Get or create a Stripe customer for a Firebase user
 */
async function getOrCreateStripeCustomer(userId: string) {
  try {
    // Check if customer already exists in Firestore
    const userDoc = await db.collection("users").doc(userId).get();
    let customerId = userDoc.data()?.stripeCustomerId;

    if (customerId) {
      // Verify customer exists in Stripe
      try {
        const customer = await stripe.customers.retrieve(customerId);
        if (!customer.deleted) {
          return customer;
        }
      } catch (error) {
        logger.warn("Stripe customer not found, creating new one", {
          userId,
          customerId,
        });
        customerId = null;
      }
    }

    // Get user details from Firebase Auth
    const userRecord = await getAuth().getUser(userId);
    
    // Create new Stripe customer
    const customer = await stripe.customers.create({
      email: userRecord.email,
      metadata: {
        firebaseUID: userId,
        app: 'zenradar',
      },
    });

    // Store customer ID in Firestore
    await db.collection("users").doc(userId).set({
      stripeCustomerId: customer.id,
      email: userRecord.email,
      updatedAt: new Date(),
    }, {merge: true});

    logger.info("New Stripe customer created", {
      userId,
      customerId: customer.id,
      email: userRecord.email,
    });

    return customer;

  } catch (error) {
    logger.error("Error getting or creating Stripe customer", {
      userId,
      error: error instanceof Error ? error.message : "Unknown error",
    });
    throw error;
  }
}

/**
 * Handle subscription created event
 */
async function handleSubscriptionCreated(subscription: any) {
  const userId = subscription.metadata?.userId;
  
  if (!userId) {
    logger.error("No userId in subscription metadata");
    return;
  }

  await db.collection("users").doc(userId).set({
    stripeSubscriptionId: subscription.id,
    stripeCustomerId: subscription.customer,
    subscriptionStatus: subscription.status,
    subscriptionTier: 'premium',
    isPremium: subscription.status === 'active',
    subscriptionCurrentPeriodStart: new Date(subscription.current_period_start * 1000),
    subscriptionCurrentPeriodEnd: new Date(subscription.current_period_end * 1000),
    subscriptionCreatedAt: new Date(),
    updatedAt: new Date(),
  }, {merge: true});

  logger.info("User subscription created", {
    userId,
    subscriptionId: subscription.id,
    status: subscription.status,
  });
}

/**
 * Handle subscription updated event
 */
async function handleSubscriptionUpdated(subscription: any) {
  const userId = subscription.metadata?.userId;
  
  if (!userId) {
    logger.error("No userId in subscription metadata");
    return;
  }

  const isPremium = subscription.status === 'active';

  await db.collection("users").doc(userId).set({
    stripeSubscriptionId: subscription.id,
    subscriptionStatus: subscription.status,
    subscriptionTier: isPremium ? 'premium' : 'free',
    isPremium: isPremium,
    subscriptionCurrentPeriodStart: new Date(subscription.current_period_start * 1000),
    subscriptionCurrentPeriodEnd: new Date(subscription.current_period_end * 1000),
    updatedAt: new Date(),
  }, {merge: true});

  logger.info("User subscription updated", {
    userId,
    subscriptionId: subscription.id,
    status: subscription.status,
    isPremium,
  });
}

/**
 * Handle subscription deleted event
 */
async function handleSubscriptionDeleted(subscription: any) {
  const userId = subscription.metadata?.userId;
  
  if (!userId) {
    logger.error("No userId in subscription metadata");
    return;
  }

  await db.collection("users").doc(userId).set({
    subscriptionStatus: 'canceled',
    subscriptionTier: 'free',
    isPremium: false,
    subscriptionCanceledAt: new Date(),
    updatedAt: new Date(),
  }, {merge: true});

  logger.info("User subscription canceled", {
    userId,
    subscriptionId: subscription.id,
  });
}

/**
 * Handle successful payment
 */
async function handlePaymentSucceeded(invoice: any) {
  const subscriptionId = invoice.subscription;
  
  if (!subscriptionId) {
    return;
  }

  try {
    const subscription = await stripe.subscriptions.retrieve(subscriptionId);
    const userId = subscription.metadata?.userId;
    
    if (!userId) {
      logger.error("No userId in subscription metadata for payment");
      return;
    }

    // Update user status to ensure they're marked as premium
    await db.collection("users").doc(userId).set({
      isPremium: true,
      subscriptionStatus: 'active',
      subscriptionTier: 'premium',
      lastPaymentAt: new Date(invoice.created * 1000),
      subscriptionCurrentPeriodEnd: new Date(invoice.period_end * 1000),
      updatedAt: new Date(),
    }, {merge: true});

    logger.info("Payment succeeded for user", {
      userId,
      subscriptionId,
      invoiceId: invoice.id,
      amount: invoice.amount_paid,
    });

  } catch (error) {
    logger.error("Error handling payment success", {error});
  }
}

/**
 * Handle failed payment
 */
async function handlePaymentFailed(invoice: any) {
  const subscriptionId = invoice.subscription;
  
  if (!subscriptionId) {
    return;
  }

  try {
    const subscription = await stripe.subscriptions.retrieve(subscriptionId);
    const userId = subscription.metadata?.userId;
    
    if (!userId) {
      logger.error("No userId in subscription metadata for failed payment");
      return;
    }

    logger.warn("Payment failed for user", {
      userId,
      subscriptionId,
      invoiceId: invoice.id,
      amount: invoice.amount_due,
    });

    // Note: Don't immediately revoke premium access on first failure
    // Stripe will retry, and we'll handle it in subscription.updated if needed

  } catch (error) {
    logger.error("Error handling payment failure", {error});
  }
}
