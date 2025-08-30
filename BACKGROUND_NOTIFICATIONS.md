# Background Push Notifications Setup

This document explains how to set up background push notifications for ZenRadar, allowing users to receive notifications even when the app is completely closed.

## Overview

ZenRadar now supports Firebase Cloud Messaging (FCM) for sending push notifications to users when their favorite matcha products come back in stock or change price, even when the app is closed or in the background.

## Architecture

### Client-Side (Flutter App)
1. **Firebase Messaging Service** (`firebase_messaging_service.dart`)
   - Handles FCM token registration
   - Manages message handlers for different app states
   - Subscribes/unsubscribes to product-specific topics

2. **Favorite Notification Service** (`favorite_notification_service.dart`)
   - Monitors favorite products for changes
   - Integrates with FCM for subscription management

3. **Notification Service** (`notification_service.dart`)
   - Shows local notifications
   - Handles notification permission requests

### Server-Side (Your Backend)
Your cloud crawler would need to be enhanced to send FCM messages when products change.

## Implementation Details

### Client Features Implemented

#### 1. FCM Token Management
- Automatically generates and stores FCM tokens
- Updates tokens when they refresh
- Stores tokens in user settings for server synchronization

#### 2. Topic Subscriptions
- Each product has a unique FCM topic: `product_{productId}`
- Users automatically subscribe when they favorite a product
- Users automatically unsubscribe when they unfavorite a product

#### 3. Message Handling
- **Foreground**: Shows local notification even when app is active
- **Background**: Handles notification taps and navigation
- **Terminated**: Processes messages when app is completely closed

#### 4. Notification Types
- **Stock Alerts**: When favorite products come back in stock
- **Price Alerts**: When favorite product prices change significantly
- **General**: App-wide announcements

### Client Integration Points

#### 1. App Initialization (`main.dart`)
```dart
// Initialize Firebase Cloud Messaging for push notifications
await FirebaseMessagingService.instance.initialize();
```

#### 2. Favorite Management (`home_screen_content.dart`)
```dart
// Subscribe to FCM notifications when favoriting
await FirebaseMessagingService.instance.subscribeToProduct(productId);

// Unsubscribe when unfavoriting
await FirebaseMessagingService.instance.unsubscribeFromProduct(productId);
```

#### 3. Permission Handling (`onboarding_screen_new.dart`)
FCM permissions are requested through the enhanced notification permission flow during onboarding.

## Server-Side Implementation Needed

To complete the background notification system, your cloud crawler needs to:

### 1. FCM Admin SDK Integration
Install Firebase Admin SDK in your cloud crawler:
```bash
npm install firebase-admin
```

### 2. Initialize FCM Admin
```javascript
const admin = require('firebase-admin');
const serviceAccount = require('./path/to/serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});
```

### 3. Send Notifications on Product Changes
```javascript
// Example: Send stock alert
async function sendStockAlert(productId, productName, siteName) {
  const message = {
    notification: {
      title: `${productName} is Back in Stock!`,
      body: `Available now on ${siteName}`,
    },
    data: {
      type: 'stock_alert',
      productId: productId,
      productName: productName,
      siteName: siteName,
    },
    topic: `product_${productId}`,
  };

  try {
    const response = await admin.messaging().send(message);
    console.log('Successfully sent message:', response);
  } catch (error) {
    console.log('Error sending message:', error);
  }
}

// Example: Send price alert
async function sendPriceAlert(productId, productName, oldPrice, newPrice) {
  const priceDirection = newPrice > oldPrice ? '📈' : '📉';
  const message = {
    notification: {
      title: `${priceDirection} Price Change: ${productName}`,
      body: `Price changed from ${oldPrice} to ${newPrice}`,
    },
    data: {
      type: 'price_alert',
      productId: productId,
      productName: productName,
      oldPrice: oldPrice.toString(),
      newPrice: newPrice.toString(),
    },
    topic: `product_${productId}`,
  };

  await admin.messaging().send(message);
}
```

### 4. Integration with Existing Crawler
Modify your crawler to detect changes and send notifications:

```javascript
// In your existing product monitoring logic
if (hasStockChanged(oldProduct, newProduct) && newProduct.isInStock) {
  await sendStockAlert(product.id, product.name, product.site);
}

if (hasPriceChanged(oldProduct, newProduct)) {
  await sendPriceAlert(product.id, product.name, oldProduct.price, newProduct.price);
}
```

## Firebase Console Setup

1. **Create Firebase Project** (if not already done)
2. **Enable Cloud Messaging**
3. **Add Android/iOS Apps** with proper package names
4. **Download Configuration Files**
   - `google-services.json` for Android
   - `GoogleService-Info.plist` for iOS
5. **Generate Server Key** for Admin SDK

## Android Configuration

Add to `android/app/build.gradle`:
```gradle
dependencies {
    implementation 'com.google.firebase:firebase-messaging:23.1.2'
}
```

## Testing

### Client-Side Testing
```dart
// Test FCM token generation
final token = FirebaseMessagingService.instance.fcmToken;
print('FCM Token: $token');

// Test topic subscription
await FirebaseMessagingService.instance.subscribeToProduct('test_product_123');
```

### Server-Side Testing
Use Firebase Console to send test messages to specific topics or tokens.

## Benefits

1. **Always Available**: Notifications work even when app is completely closed
2. **Battery Efficient**: Uses system-level push notification infrastructure
3. **Reliable**: Built on Firebase's proven messaging infrastructure
4. **Scalable**: Can handle millions of users
5. **Cross-Platform**: Works on Android, iOS, and Web

## Limitations

1. **Requires Server**: Backend must implement FCM Admin SDK
2. **Internet Required**: Push notifications require internet connectivity
3. **Permission Dependent**: Users must grant notification permissions

## Future Enhancements

1. **Rich Notifications**: Add images, action buttons
2. **Scheduled Notifications**: Send reminders at optimal times
3. **Analytics**: Track notification engagement
4. **Personalization**: Customize notification timing per user
