# Payment Processing Setup Guide for ZenRadar

## Overview
This guide will help you implement a **completely free** payment processing system using Stripe + Firebase that handles premium subscriptions automatically.

## 🎯 What You Get
- ✅ **Free for you**: Only pay Stripe's transaction fees (2.9% + 30¢)
- ✅ **Zero monthly costs**: No platform fees or subscription management costs
- ✅ **Automatic premium status**: Users get premium access immediately after payment
- ✅ **Self-service**: Users can cancel/modify subscriptions themselves
- ✅ **Secure**: Stripe handles all payment security (PCI compliant)
- ✅ **Global**: Works worldwide with local payment methods

---

## Step 1: Create Stripe Account & Products

### 1.1 Sign up for Stripe
1. Go to [https://stripe.com](https://stripe.com)
2. Create a free account
3. Complete business verification (required for live payments)

### 1.2 Create Products & Prices
In your Stripe Dashboard:

1. **Go to Products** → Create product:
   - **Name**: ZenRadar Premium Monthly
   - **Description**: Premium matcha monitoring with unlimited access
   - **Pricing**: Recurring, $2.99/month

2. **Copy the Price ID** (starts with `price_`):
   ```
   price_1Ox7abc123def... <- Copy this
   ```

3. **Create yearly product**:
   - **Name**: ZenRadar Premium Yearly
   - **Pricing**: Recurring, $29.99/year
   - **Copy this Price ID too**

### 1.3 Get API Keys
In Stripe Dashboard → Developers → API keys:
- **Publishable key**: `pk_test_...` (for frontend)
- **Secret key**: `sk_test_...` (for backend)
- **Webhook secret**: We'll create this next

---

## Step 2: Set Up Webhooks

### 2.1 Create Webhook Endpoint
1. **Stripe Dashboard** → Developers → Webhooks → Add endpoint
2. **Endpoint URL**: `https://your-region-your-project.cloudfunctions.net/handleStripeWebhook`
3. **Select events to listen to**:
   ```
   customer.subscription.created
   customer.subscription.updated  
   customer.subscription.deleted
   invoice.payment_succeeded
   invoice.payment_failed
   ```
4. **Copy the webhook secret**: `whsec_...`

---

## Step 3: Configure Firebase Functions

### 3.1 Set Environment Variables
Run these commands in your `functions/` directory:

```bash
# Install dependencies
npm install

# Set Stripe keys
firebase functions:config:set stripe.secret_key="sk_test_your_secret_key"
firebase functions:config:set stripe.webhook_secret="whsec_your_webhook_secret"
```

### 3.2 Update Price IDs
In `lib/services/payment_service.dart`, update these lines:

```dart
// Replace with your actual Stripe price IDs
static const String monthlyPriceId = 'price_1Ox7abc123def...'; // Your monthly price ID
static const String yearlyPriceId = 'price_1Ox8def456ghi...';  // Your yearly price ID
```

### 3.3 Update Firebase Functions URL
In `lib/services/payment_service.dart`, update:

```dart
static const String _functionsBaseUrl = 
    'https://your-region-your-project-id.cloudfunctions.net';
```

---

## Step 4: Deploy Functions

```bash
# Navigate to functions directory
cd functions

# Build and deploy
npm run build
firebase deploy --only functions
```

**Important**: After deployment, copy the webhook URL from the deploy output and update your Stripe webhook endpoint.

---

## Step 5: Test the Implementation

### 5.1 Test Mode
- Stripe starts in test mode by default
- Use test card: `4242 4242 4242 4242` (any CVC, future date)
- Test the full flow: upgrade → checkout → webhook → premium status

### 5.2 Test Subscription Flow
1. **User clicks "Upgrade"** → Opens Stripe Checkout
2. **User completes payment** → Stripe processes payment
3. **Stripe sends webhook** → Firebase updates user status
4. **User gets premium access** → App refreshes premium status

---

## Step 6: Go Live

### 6.1 Switch to Live Mode
1. **Stripe Dashboard** → Toggle to "Live mode"
2. **Create new products** with live price IDs
3. **Update functions config** with live keys:
   ```bash
   firebase functions:config:set stripe.secret_key="sk_live_..."
   firebase functions:config:set stripe.webhook_secret="whsec_live_..."
   ```
4. **Deploy functions** again
5. **Update webhook URL** to live functions URL

### 6.2 Update App Config
Update price IDs in `payment_service.dart` with live price IDs.

---

## Step 7: Add Subscription Management

### 7.1 Customer Portal
Users can manage subscriptions via Stripe's Customer Portal:
- Cancel subscriptions
- Update payment methods
- View billing history
- Download invoices

### 7.2 Add to Settings Screen
In your settings screen, add this button:

```dart
ElevatedButton(
  onPressed: () async {
    try {
      await PaymentService.instance.openSubscriptionManagement();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  },
  child: Text('Manage Subscription'),
)
```

---

## 🔄 How It Works (User Flow)

1. **User clicks "Upgrade"** in your app
2. **App calls Firebase Function** → Creates Stripe checkout session
3. **User redirected to Stripe** → Secure payment form
4. **Payment completed** → Stripe webhook fires
5. **Firebase Function triggered** → Updates user's premium status in Firestore
6. **App syncs status** → User immediately gets premium access

---

## 💰 Costs Breakdown

### What's Free:
- ✅ Firebase Functions (generous free tier)
- ✅ Firestore database operations
- ✅ Stripe Customer Portal
- ✅ Webhook processing
- ✅ Subscription management

### What Costs Money:
- 💳 **Stripe fees only**: 2.9% + 30¢ per successful charge
- 💳 **Example**: $2.99 subscription = $0.39 fee (you keep $2.60)

### Total Monthly Costs:
- **0 subscribers**: $0.00
- **100 subscribers**: $0.00 platform fees (only Stripe transaction fees)
- **1000 subscribers**: $0.00 platform fees (only Stripe transaction fees)

---

## 🛡️ Security Features

- **PCI Compliance**: Stripe handles all card data
- **Fraud Protection**: Built-in Stripe Radar
- **Webhook Verification**: Cryptographically signed webhooks
- **Firebase Auth**: Secure user authentication
- **Environment Variables**: API keys stored securely

---

## 📊 Analytics & Monitoring

### Track in Firebase Console:
- Function execution logs
- Error rates
- Performance metrics

### Track in Stripe Dashboard:
- Revenue analytics
- Churn rates
- Payment success rates
- Customer lifetime value

---

## 🆘 Troubleshooting

### Common Issues:

**1. Webhook not firing**
- Check webhook endpoint URL matches deployed function
- Verify webhook secret matches config
- Check Stripe webhook delivery attempts

**2. Premium status not updating**
- Check Firebase Function logs
- Verify user ID in webhook metadata
- Ensure Firestore security rules allow writes

**3. Checkout not loading**
- Verify price IDs are correct
- Check CORS settings
- Ensure user is authenticated

### Debug Commands:
```bash
# Check function logs
firebase functions:log

# Test webhook locally
firebase emulators:start --only functions

# Check config
firebase functions:config:get
```

---

## 🚀 Ready to Launch!

With this setup, you have:
- ✅ Production-ready payment processing
- ✅ Automatic premium user management  
- ✅ Global payment support
- ✅ Self-service subscription management
- ✅ Zero platform fees
- ✅ Enterprise-grade security

Your users can now upgrade to premium and get immediate access to all premium features!
