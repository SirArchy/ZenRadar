const ShoChaSpecializedCrawler = require('./sho-cha-crawler');
const PoppateaSpecializedCrawler = require('./poppatea-crawler');
const HoriishichimeienSpecializedCrawler = require('./horiishichimeien-crawler');
const MatchaKaruSpecializedCrawler = require('./matcha-karu-crawler');
const MarukyuKoyamaenSpecializedCrawler = require('./marukyu-koyamaen-crawler');
const IppodoTeaSpecializedCrawler = require('./ippodo-tea-crawler');
const SazenteaSpecializedCrawler = require('./sazentea-crawler');

/**
 * Factory for creating specialized crawlers for different sites
 */
class SiteCrawlerFactory {
  /**
   * Get specialized crawler for a site, or null for default crawling
   */
  static getCrawler(siteKey, logger) {
    switch (siteKey) {
      case 'sho-cha':
        return new ShoChaSpecializedCrawler(logger);
      
      case 'poppatea':
        return new PoppateaSpecializedCrawler(logger);
      
      case 'horiishichimeien':
        return new HoriishichimeienSpecializedCrawler(logger);
      
      case 'matcha-karu':
        return new MatchaKaruSpecializedCrawler(logger);
      
      case 'marukyu-koyamaen':
        return new MarukyuKoyamaenSpecializedCrawler(logger);
      
      case 'ippodo-tea':
        return new IppodoTeaSpecializedCrawler(logger);
      
      case 'sazentea':
        return new SazenteaSpecializedCrawler(logger);
      
      default:
        return null; // Use default crawler logic
    }
  }

  /**
   * Check if a site has a specialized crawler
   */
  static hasSpecializedCrawler(siteKey) {
    return [
      'sho-cha', 
      'poppatea', 
      'horiishichimeien', 
      'matcha-karu', 
      'marukyu-koyamaen', 
      'ippodo-tea', 
      'sazentea'
    ].includes(siteKey);
  }

  /**
   * Get list of sites with specialized crawlers
   */
  static getSpecializedSites() {
    return [
      'sho-cha', 
      'poppatea', 
      'horiishichimeien', 
      'matcha-karu', 
      'marukyu-koyamaen', 
      'ippodo-tea', 
      'sazentea'
    ];
  }
}

module.exports = SiteCrawlerFactory;
