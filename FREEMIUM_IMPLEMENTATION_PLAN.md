# 🎯 ZenRadar Freemium Model Implementation Plan

## 📊 **Current State Analysis**

### **Existing Infrastructure:**
- ✅ Firebase Auth (for user identification)
- ✅ FCM Push Notifications (favorite products)
- ✅ Firestore (product data storage)
- ✅ UserSettings system (preferences persistence)
- ✅ Background monitoring (favorite notification service)
- ✅ Analytics system (stock history tracking)

### **Key Files/Services Affected:**
1. **UserSettings Model** (`lib/models/matcha_product.dart`)
2. **Settings Service** (`lib/services/settings_service.dart`)
3. **Firebase Messaging Service** (`lib/services/firebase_messaging_service.dart`)
4. **Favorite Notification Service** (`lib/services/favorite_notification_service.dart`)
5. **Database Services** (`lib/services/database_service.dart`, `lib/services/firestore_service.dart`)
6. **UI Components** (Settings screen, Home screen, etc.)

---

## 🎯 **Freemium Tier Specification**

### **Free Tier Limits:**
- **Vendors**: Monitor only 4-5 out of 10 available vendors
- **Favorites**: Maximum 15 favorite products
- **Check Frequency**: Every 6 hours (360 minutes)
- **Analytics**: Last 7 days of stock history only
- **Notifications**: Standard push notifications only

### **Premium Tier Benefits:**
- **Vendors**: Monitor all 10+ vendors simultaneously
- **Favorites**: Unlimited favorite products
- **Check Frequency**: Every hour (60 minutes) or 30 minutes
- **Analytics**: Full history + advanced insights
- **Notifications**: Priority notifications, custom rules, summary reports

---

## 🏗️ **Implementation Phases**

### **Phase 1: Foundation - Subscription Model** ⏱️ 2-3 hours

#### 1.1 Extend UserSettings Model
```dart
enum SubscriptionTier { free, premium }

class UserSettings {
  // Existing fields...
  final SubscriptionTier subscriptionTier;
  final DateTime? subscriptionExpiresAt;
  final String? subscriptionId; // RevenueCat/Stripe ID
  final DateTime? lastTierCheck;
}
```

#### 1.2 Create Subscription Service
```dart
class SubscriptionService {
  // Tier validation
  Future<bool> isPremiumUser();
  Future<SubscriptionTier> getCurrentTier();
  
  // Limit checks
  Future<bool> canAddMoreFavorites();
  Future<bool> canEnableMoreVendors();
  Future<bool> canAccessFullHistory();
  
  // Premium features
  Future<bool> canSetFastCheckFrequency();
  Future<bool> canUsePriorityNotifications();
}
```

#### 1.3 Update Settings Service
- Add subscription persistence methods
- Validation for tier-based settings

### **Phase 2: Service Layer - Limits & Validation** ⏱️ 4-5 hours

#### 2.1 Vendor Monitoring Limits
- Modify `enabledSites` logic in UserSettings
- Add validation in Settings screen
- Default free users to 4-5 popular vendors (Tokichi, Marukyu, Ippodo, Ippodo, Yoshien)

#### 2.2 Favorites Limits
- Modify `BackendService.updateFavorite()` to check limits
- Add counter validation before adding favorites
- UI feedback when limit reached

#### 2.3 Check Frequency Limits
- Modify `checkFrequencyMinutes` validation
- Free: Minimum 360 minutes (6 hours)
- Premium: Minimum 60 minutes (1 hour), later 30 minutes

#### 2.4 Analytics/History Limits
- Modify `getStockHistoryForProduct()` to filter by tier
- Free: Only last 7 days of data
- Premium: Full historical data

### **Phase 3: UI Layer - Premium Prompts & Indicators** ⏱️ 3-4 hours

#### 3.1 Subscription Status UI
- Add tier indicator to Settings screen
- Subscription expiry warnings
- Premium benefits showcase

#### 3.2 Limit-Reached Prompts
- Favorites limit modal with upgrade CTA
- Vendor selection limit warnings
- Analytics history upgrade prompts

#### 3.3 Settings Tiers
- Visual distinction between free/premium settings
- Lock icons for premium-only features
- Upgrade buttons throughout the app

### **Phase 4: Payment Integration** ⏱️ 6-8 hours

#### 4.1 RevenueCat Setup (Mobile)
```yaml
dependencies:
  purchases_flutter: ^6.0.0
```

#### 4.2 Stripe Setup (Web)
```yaml
dependencies:
  stripe_checkout: ^2.0.0
```

#### 4.3 Backend Integration
- Firebase Functions for subscription webhook handling
- RevenueCat webhook for mobile subscription events
- Stripe webhook for web subscription events

---

## 🛠️ **Technical Implementation Details**

### **Free Tier Default Configuration:**
```dart
static const FREE_TIER_DEFAULTS = {
  'maxFavorites': 15,
  'maxVendors': 4,
  'minCheckFrequencyMinutes': 360, // 6 hours
  'historyLimitDays': 7,
  'defaultEnabledSites': ['tokichi', 'marukyu', 'ippodo', 'yoshien'],
};
```

### **Subscription State Management:**
```dart
class SubscriptionState extends ChangeNotifier {
  SubscriptionTier _tier = SubscriptionTier.free;
  DateTime? _expiresAt;
  
  bool get isPremium => _tier == SubscriptionTier.premium;
  bool get isExpired => _expiresAt?.isBefore(DateTime.now()) ?? false;
  
  void updateSubscription(SubscriptionTier tier, DateTime? expiresAt) {
    _tier = tier;
    _expiresAt = expiresAt;
    notifyListeners();
  }
}
```

### **Limit Enforcement Points:**
1. **Favorites Addition**: `BackendService.updateFavorite()`
2. **Vendor Selection**: Settings screen site selection
3. **Frequency Setting**: Settings screen check frequency
4. **History Access**: Analytics screens and charts
5. **Notification Features**: FCM service configuration

---

## 💰 **Revenue Model Recommendations**

### **Pricing Strategy:**
- **Free Tier**: Permanently free with clear limitations
- **Premium Tier**: $2.99/month or $29.99/year (65% savings)
- **Trial**: 7-day free trial for premium features

### **Upgrade Triggers:**
1. **Favorites Limit**: "You've reached 15 favorites! Upgrade to add unlimited favorites"
2. **Vendor Limit**: "Want to monitor all matcha vendors? Upgrade for complete coverage"
3. **Speed Limit**: "Get notified faster! Premium users get hourly updates"
4. **History Limit**: "Unlock full analytics history with Premium"

### **Payment Flow Architecture:**
```
Mobile App (Android) → RevenueCat → Google Play → Firebase Functions
Web App → Stripe Checkout → Stripe Webhooks → Firebase Functions
All Platforms → Firestore (subscription status sync)
```

---

## 🧪 **Testing Strategy**

### **Free Tier Testing:**
- [ ] Favorites limited to 15
- [ ] Only 4 vendors selectable
- [ ] Check frequency minimum 6 hours
- [ ] History limited to 7 days
- [ ] Upgrade prompts appear at limits

### **Premium Tier Testing:**
- [ ] Unlimited favorites
- [ ] All vendors available
- [ ] 1-hour minimum check frequency
- [ ] Full history access
- [ ] No limit prompts

### **Payment Testing:**
- [ ] RevenueCat sandbox (mobile)
- [ ] Stripe test mode (web)
- [ ] Webhook delivery
- [ ] Subscription state sync

---

## 📅 **Implementation Timeline**

| Phase | Tasks | Time Estimate | Status |
|-------|-------|---------------|---------|
| Phase 1 | Subscription model foundation | 2-3 hours | 🔄 Ready |
| Phase 2 | Service layer limits | 4-5 hours | ⏳ Next |
| Phase 3 | UI prompts & indicators | 3-4 hours | ⏳ Pending |
| Phase 4 | Payment integration | 6-8 hours | ⏳ Pending |
| **Total** | **Complete freemium system** | **15-20 hours** | ⏳ Planning |

---

## 🚀 **Launch Strategy**

### **Soft Launch:**
1. Deploy with free tier as default
2. Monitor user behavior and limit-hitting patterns
3. A/B test upgrade prompts effectiveness

### **Premium Launch:**
1. Enable payment processing
2. Email existing users about new premium features
3. Offer limited-time discount for early adopters

### **Post-Launch Optimization:**
1. Analytics on conversion rates
2. User feedback on premium features
3. Iterative improvements to upgrade flow

---

**Status**: 📋 Planning Complete - Ready for Implementation
**Next Step**: Phase 1 - Foundation Implementation
