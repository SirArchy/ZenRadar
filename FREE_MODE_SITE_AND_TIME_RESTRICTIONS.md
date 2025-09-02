# 🔒 Free Mode Site and Time Range Restrictions

## Overview
This document outlines the implemented restrictions for free tier users regarding available websites and time range access.

## 📍 Free Mode Website Restrictions

### Available Sites for Free Users
Free tier users can only monitor these 5 matcha websites:
1. **Ippodo** - Premium tea house
2. **Marukyu** (Marukyu-Koyamaen) - Historic Kyoto tea company  
3. **Nakamura** - Authentic Japanese matcha
4. **Matcha Karu** - Organic matcha specialist
5. **YOSHI En** - German matcha retailer

### Premium Sites (Premium Only)
- Tokichi
- Sho-Cha
- Sazen Tea
- Enjoy Emeri
- Poppa Tea
- Horiishichimeien

## ⏰ Time Range Restrictions

### Product Details Page
- **Free Users**: Only "7 Days" option available
- **Premium Users**: Full access to "7 Days", "1 Month", "1 Year", "All Time"

### Website Overview Screen  
- **Free Users**: Only "Last 7 days" option available
- **Premium Users**: Full access to "Last 24 hours", "Last 7 days", "Last 30 days", "All time"

## 🔧 Implementation Details

### Files Modified

#### 1. Core Model Updates
- `lib/models/matcha_product.dart`
  - Updated `freeEnabledSites` list to new 5 sites
  - Changed `maxVendorsForFree` from 4 to 5
  - Updated default enabled sites order

#### 2. Settings Screen
- `lib/screens/settings_screen.dart`
  - Updated `_getBuiltInSites()` to filter based on subscription tier
  - Free users only see the 5 allowed sites
  - Added subscription tier filtering logic

#### 3. Home Screen
- `lib/screens/home_screen_content.dart`
  - Modified `_loadFilterOptions()` to filter available sites by subscription tier
  - Free users only see allowed sites in filters

#### 4. Product Detail Page
- `lib/screens/product_detail_page.dart`
  - Added time range restrictions to both price and stock history popups
  - Free users only see "7 Days" option
  - Updated labels to show "Last 7 Days" for free users
  - Auto-defaults to 'day' option for free users

#### 5. Website Overview Screen
- `lib/screens/website_overview_screen.dart`
  - Added subscription status loading
  - Filtered time range picker to only show 'day' option for free users
  - Updated labels to show "Last 7 days" for free users in day mode
  - Auto-defaults to 'day' option for free users

#### 6. Site Selection Dialog
- `lib/widgets/site_selection_dialog.dart`
  - Added description for 'nakamura' site

## 🎯 User Experience

### Free User Flow
1. **Site Selection**: Only sees 5 premium matcha sites
2. **Time Ranges**: Limited to 7-day views across all analytics
3. **Upgrade Prompts**: Clear indication that more sites and time ranges are available with Premium

### Premium User Flow
1. **Site Selection**: Access to all 11+ monitored sites
2. **Time Ranges**: Full access to all time range options
3. **No Restrictions**: Complete feature access

## 🔄 Data Handling

### Site Filtering
- Applied at multiple levels: settings, home screen, and database queries
- Maintains data integrity while restricting UI access
- Premium users see all sites immediately upon upgrade

### Time Range Filtering  
- UI-level restrictions only (data is still collected)
- Quick access to full history upon Premium upgrade
- No data loss during tier transitions

## ✅ Validation Points

### Free Tier Limits Enforced:
- [x] Only 5 specific matcha sites visible/selectable
- [x] Product detail charts limited to 7 days
- [x] Website overview limited to 7 days  
- [x] Settings screen shows only allowed sites
- [x] Home screen filters show only allowed sites
- [x] Default time ranges set to allowed options

### Premium Benefits:
- [x] All 11+ sites accessible
- [x] Full time range options available
- [x] No feature limitations
- [x] Immediate access upon upgrade

## 📝 Notes

- Site filtering is applied at the UI level to maintain performance
- Historical data is preserved for Premium upgrade scenarios  
- The 'day' option for free users actually shows 7 days of data (not 24 hours)
- All restrictions are subscription-tier aware and update dynamically
- Free users are guided toward Premium with clear benefit messaging
