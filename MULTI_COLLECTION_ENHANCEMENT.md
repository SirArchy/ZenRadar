# ZenRadar Multi-Collection Crawler Enhancement

## Summary
Enhanced the ZenRadar crawler to capture products from ALL tea categories, not just matcha, by implementing multi-URL crawling per site and leveraging the existing automatic category detection system.

## Key Changes Made

### 1. Enhanced SiteConfig Class
- **Added**: `additionalUrls` field to support multiple collection URLs per site
- **Added**: `allUrls` getter method to combine base URL with additional URLs
- **Maintains**: Full backward compatibility with existing single-URL configurations

### 2. Updated Site Configurations

#### Tokichi (7 collections)
- Matcha, Genmaicha, Hojicha, Sencha, Gyokuro, Green Tea, Teaware

#### Marukyu-Koyamaen (5 collections) 
- Matcha, Sencha, Gyokuro, Genmaicha, Hojicha

#### Ippodo Tea (comprehensive)
- Changed to "All Products" collection for complete coverage

#### Matcha Kāru (4 collections)
- Matcha Tea, Tea Ceremony, Accessories, Gift Sets

#### Sazen Tea (6 collections)
- Matcha, Sencha, Gyokuro, Hojicha, Tea Accessories, Teapots & Teacups

### 3. Enhanced crawlSite Method
- **Multi-URL Processing**: Crawls each collection URL sequentially
- **Duplicate Prevention**: Removes products with duplicate URLs across collections
- **Progress Logging**: Enhanced logging shows collection progress (X/Y collections)
- **Rate Limiting**: 500ms delay between collection requests to be respectful
- **Error Handling**: Individual collection errors don't stop the entire site crawl

### 4. Automatic Category Detection
Leverages existing `MatchaProduct.detectCategory()` logic which recognizes:
- **Tea Types**: Matcha, Sencha, Gyokuro, Hojicha, Genmaicha, Black Tea
- **Accessories**: Whisks, bowls, scoops, teaware, tools
- **Sets**: Gift sets, tea ceremony kits
- **Default Fallback**: Smart defaults based on site context

## Benefits

### For Users
✅ **Complete Product Discovery**: Find all tea products, not just matcha  
✅ **Enhanced Filtering**: Use category filters effectively with comprehensive data  
✅ **Better Price Tracking**: Monitor prices across all tea categories  
✅ **Accessory Tracking**: Track teaware and ceremony tools  

### For the App
✅ **Improved Category Distribution**: Better balance across product categories  
✅ **Enhanced Search Results**: More relevant results for non-matcha searches  
✅ **Future-Proof**: Easy to add new collections as sites expand  
✅ **Performance Optimized**: Duplicate detection prevents database bloat  

## Technical Implementation

### Crawling Flow
1. **Site Selection**: User or scheduler selects sites to crawl
2. **Collection Discovery**: `config.allUrls` provides all URLs for the site
3. **Sequential Processing**: Each collection URL crawled with progress tracking
4. **Duplicate Filtering**: Products filtered by URL to prevent duplicates
5. **Category Detection**: `MatchaProduct.detectCategory()` automatically categorizes
6. **Database Storage**: Products stored with detected categories

### Performance Considerations
- **Rate Limiting**: 500ms delays between requests respect website resources
- **Error Isolation**: Individual collection failures don't break entire crawl
- **Duplicate Prevention**: URL-based deduplication saves storage and processing
- **Scalable Design**: Easy to add more collections without code changes

## Backward Compatibility
✅ **Existing Sites**: Sites without `additionalUrls` work exactly as before  
✅ **Database Schema**: No changes to existing product data structure  
✅ **UI Components**: Category filters already support detected categories  
✅ **API Compatibility**: All existing crawler methods unchanged  

## Future Enhancements
- **Dynamic Collection Discovery**: Automatically detect new collections from site sitemaps
- **Collection-Specific Selectors**: Different CSS selectors per collection if needed
- **Priority Crawling**: Crawl popular collections first
- **Collection Scheduling**: Different update frequencies per collection type

## Testing
- **Compilation**: ✅ Flutter analyze passes with no errors
- **Category Detection**: ✅ Comprehensive test examples working
- **Site Configuration**: ✅ All enhanced sites properly configured
- **Duplicate Prevention**: ✅ URL-based deduplication logic implemented

The enhanced crawler now provides comprehensive tea product discovery while maintaining the high quality and reliability that ZenRadar users expect.
