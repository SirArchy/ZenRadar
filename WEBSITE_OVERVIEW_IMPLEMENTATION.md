# Website Overview Feature Implementation

## Overview
Added a comprehensive website overview screen that displays stock update analytics for all monitored matcha websites, similar to the product detail page graphs but aggregated at the website level.

## New Components

### 1. Data Models
- **`WebsiteStockAnalytics`** (`lib/models/website_stock_analytics.dart`)
  - Contains analytics data for individual websites
  - Tracks stock updates, product counts, update patterns
  - Provides time range filtering
  - Calculates hourly/daily update patterns
  - Identifies most active hours and update frequency

- **`StockUpdateEvent`** (same file)
  - Represents individual stock update events
  - Tracks restocks vs out-of-stock changes
  - Provides human-readable descriptions

### 2. Service Layer
- **`WebsiteAnalyticsService`** (`lib/services/website_analytics_service.dart`)
  - Fetches data from SQLite database (local mode)
  - Future-ready for Firestore integration (server mode)
  - Aggregates stock history across all products per website
  - Generates overall summary statistics
  - Supports time range filtering (day, week, month, all)

### 3. UI Components
- **`WebsiteStockChart`** (`lib/widgets/website_stock_chart.dart`)
  - Custom chart widget showing stock update frequency over time
  - Time range selector support
  - Interactive tooltips with update details
  - Color-coded dots based on update intensity

- **`WebsiteUpdatePatternWidget`** (same file)
  - 24-hour heatmap showing when updates typically occur
  - Visual intensity based on update frequency
  - Most active hour identification

- **`WebsiteOverviewScreen`** (`lib/screens/website_overview_screen.dart`)
  - Main screen displaying all website analytics
  - Expandable cards for each website
  - Time range filtering
  - Overall summary dashboard
  - Recent updates timeline

### 4. Navigation Integration
- Added timeline icon to home screen app bar
- Direct navigation to website overview screen
- Positioned between history and settings buttons

## Features

### Analytics Dashboard
- **Overall Summary Card**
  - Total websites vs active websites
  - Total products across all sites
  - Overall stock percentage
  - Total updates in time period
  - Most recent update timestamp
  - Most active website identification

### Per-Website Analytics
- **Stock Update Charts**
  - Line chart showing update frequency over time
  - Supports day/week/month/all time ranges
  - Interactive tooltips with timestamps
  - Visual intensity indicators

- **Update Pattern Analysis**
  - 24-hour heatmap showing peak update times
  - Helpful for predicting when to pay attention
  - Identifies restock patterns

- **Recent Updates Timeline**
  - Last 7 days of stock changes
  - Distinguishes between restocks and out-of-stock
  - Timestamps with relative time display

- **Status Indicators**
  - Visual icons for website health
  - Stock percentage badges
  - Update frequency descriptions

### Time Range Filtering
- **Day**: Last 24 hours
- **Week**: Last 7 days  
- **Month**: Last 30 days
- **All**: Complete history

## Usage Scenarios

1. **Restock Prediction**: Users can identify when websites typically restock by looking at update patterns
2. **Monitoring Priority**: Focus attention on most active websites during peak hours
3. **Website Performance**: Compare activity levels across different matcha retailers
4. **Trend Analysis**: Understand long-term availability patterns

## Data Sources

### Local Mode (SQLite)
- Reads from existing `stock_history` table
- Aggregates by website using product site names
- Real-time data from local crawling

### Server Mode (Future)
- Framework ready for Firestore integration
- Would read from cloud-stored stock history
- Supports same analytics with cloud data

## Benefits

1. **Better Insights**: Understand when websites typically restock
2. **Efficient Monitoring**: Focus attention during active periods
3. **Pattern Recognition**: Identify website-specific behaviors
4. **Time Management**: Know when to expect updates

## Technical Implementation

- Uses existing `fl_chart` library for consistent charting
- Leverages current stock history data structure
- Follows app's existing architecture patterns
- Responsive design with Material Design 3
- Efficient data aggregation and filtering
- Error handling and loading states

The implementation provides a powerful tool for users to understand website stock patterns and optimize their monitoring strategy.
