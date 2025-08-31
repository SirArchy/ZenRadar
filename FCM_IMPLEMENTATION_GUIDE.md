# 🔔 Firebase Cloud Messaging (FCM) Implementation Guide

## 📋 Overview

I've implemented a complete Firebase Cloud Messaging solution that enables push notifications for your ZenRadar app. Here's what has been added:

## 🚀 What's Been Implemented

### 1. **Firebase Functions (Backend)**

#### New Functions Added:
- `registerFCMToken` - Registers user's FCM token for push notifications
- `sendStockChangeNotification` - Automatically sends notifications when products come back in stock
- `updateUserFavorites` - Manages user favorites and FCM subscriptions

#### How It Works:
- When users favorite products, their FCM tokens are associated with those products
- When the crawler detects stock changes, automatic push notifications are sent
- Invalid tokens are automatically cleaned up

### 2. **Flutter App (Frontend)**

#### Enhanced `FirebaseMessagingService`:
- **Automatic Token Registration**: Sends FCM tokens to your Firebase backend
- **Smart Subscriptions**: Automatically subscribes to notifications for favorited products
- **Multi-Platform Support**: Works on Android, iOS, and Web
- **Anonymous User Support**: Creates anonymous users if needed

#### New `BackendService`:
- **Favorite Management**: Syncs favorites with Firebase backend
- **Manual Crawl Triggers**: Allows users to trigger crawls from the app
- **FCM Integration**: Handles all backend communication

## 🔧 Implementation Details

### Firebase Functions Endpoints:

```typescript
// Register FCM Token
POST /registerFCMToken
{
  "token": "fcm_token_here",
  "userId": "user_id",
  "platform": "android|ios|web",
  "appVersion": "1.0.0"
}

// Update User Favorites
POST /updateUserFavorites
{
  "userId": "user_id",
  "productId": "product_id",
  "isFavorite": true|false
}

// Trigger Manual Crawl
POST /triggerManualCrawl
{
  "userId": "user_id",
  "sites": ["site1", "site2"] // optional
}
```

### Flutter Integration:

```dart
// Initialize FCM (call this in your main app initialization)
await BackendService.instance.initializeFCM();

// When user adds/removes favorites
await BackendService.instance.updateFavorite(
  productId: 'product_123',
  isFavorite: true,
);

// Trigger manual crawl
await BackendService.instance.triggerManualCrawl(
  sites: ['tokichi', 'marukyu'], // optional
);
```

## 📱 How Users Will Experience It

### 1. **First Time Setup**:
- User opens app → FCM requests permission → Token registered automatically
- User favorites products → Subscribed to notifications for those products

### 2. **Stock Notifications**:
- Crawler detects product is back in stock
- Push notification sent: "🎉 Back in Stock! [Product Name] is now available at [Site]"
- User taps notification → Opens app (navigation can be implemented)

### 3. **Background Operation**:
- Notifications work even when app is completely closed
- Uses Duolingo-style background push notifications

## 🔐 Firebase Security

### Firestore Rules Needed:
```javascript
// Add these rules to your firestore.rules
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // FCM Tokens - users can only access their own tokens
    match /fcm_tokens/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // User Favorites - users can only access their own favorites
    match /user_favorites/{favoriteId} {
      allow read, write: if request.auth != null && 
        resource.data.userId == request.auth.uid;
    }
    
    // Allow read access to products for all authenticated users
    match /products/{productId} {
      allow read: if request.auth != null;
    }
    
    // Stock history - read only for authenticated users
    match /stock_history/{historyId} {
      allow read: if request.auth != null;
    }
  }
}
```

## 🛠 Integration Steps

### 1. **Update Your Main App File** (`main.dart`):
```dart
import 'services/backend_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Initialize FCM
  await BackendService.instance.initializeFCM();
  
  runApp(MyApp());
}
```

### 2. **Update Favorite Button Logic**:
```dart
// Replace your existing favorite toggle logic with:
await BackendService.instance.updateFavorite(
  productId: product.id,
  isFavorite: !currentFavoriteStatus,
);
```

### 3. **Add Manual Refresh Option**:
```dart
// In your refresh logic, you can now trigger server-side crawling:
await BackendService.instance.triggerManualCrawl();
```

## 📊 Firebase Collections Structure

The implementation creates these Firestore collections:

```
fcm_tokens/
  {userId}/
    - token: string
    - platform: string
    - appVersion: string
    - lastUpdated: timestamp
    - isActive: boolean

user_favorites/
  {userId}_{productId}/
    - userId: string
    - productId: string
    - createdAt: timestamp
    - isActive: boolean

users/
  {userId}/
    - fcmToken: string (latest)
    - lastTokenUpdate: timestamp

crawl_requests/
  {requestId}/
    - triggerType: "manual" | "scheduled"
    - userId: string
    - sites: string[]
    - status: "pending" | "processing" | "running" | "completed" | "failed"
    - createdAt: timestamp
```

## 🔍 Testing

### Test Push Notifications:
1. Run the app and favorite a product
2. Check Firebase Console → Cloud Messaging to verify token registration
3. Manually trigger a crawl that changes stock status
4. Verify push notification is received

### Debug Logs:
- All FCM operations are logged with emoji prefixes (🔔, 📱, ✅, ❌)
- Check Flutter logs for FCM token registration
- Check Firebase Functions logs for backend operations

## 🚀 Production Deployment

### 1. **Deploy Firebase Functions**:
```bash
cd functions
npm run build
firebase deploy --only functions
```

### 2. **Update Firebase Project Settings**:
- Ensure your Firebase project has Cloud Messaging enabled
- Add your app's SHA-256 fingerprints in Firebase Console
- Enable Anonymous Authentication in Firebase Console

### 3. **Test End-to-End**:
- Test on real devices (Android/iOS)
- Verify notifications work when app is closed
- Test with multiple users favoriting the same product

## 🔧 Customization Options

### Notification Customization:
- Edit notification titles/messages in `sendStockChangeNotification` function
- Add custom notification icons and sounds
- Implement notification click handling for deep linking

### Advanced Features You Can Add:
- Price change notifications
- Personalized notification timing (user preferences)
- Notification categories (stock vs price alerts)
- Rich notifications with product images

This implementation provides a solid foundation for push notifications and can be extended based on your specific needs!
