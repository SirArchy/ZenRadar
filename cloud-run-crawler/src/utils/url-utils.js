/**
 * URL utilities for handling redirects, cleaning URLs, and building product links
 */
class URLUtils {
  constructor() {
    this.axios = require('axios');
  }

  /**
   * Clean and normalize URLs
   */
  cleanUrl(url) {
    if (!url) return url;
    
    // Remove query parameters that don't affect the product
    const cleanedUrl = url.split('?')[0];
    
    // Ensure proper protocol
    if (cleanedUrl.startsWith('//')) {
      return 'https:' + cleanedUrl;
    }
    
    if (!cleanedUrl.startsWith('http')) {
      return 'https://' + cleanedUrl;
    }
    
    return cleanedUrl;
  }

  /**
   * Build absolute URL from relative URL and base URL
   */
  buildAbsoluteUrl(relativeUrl, baseUrl) {
    if (!relativeUrl) return baseUrl;
    
    // If already absolute, return as-is
    if (relativeUrl.startsWith('http')) {
      return relativeUrl;
    }
    
    // Handle protocol-relative URLs
    if (relativeUrl.startsWith('//')) {
      const protocol = baseUrl.split('://')[0];
      return protocol + ':' + relativeUrl;
    }
    
    // Handle absolute paths
    if (relativeUrl.startsWith('/')) {
      const urlObj = new URL(baseUrl);
      return urlObj.protocol + '//' + urlObj.host + relativeUrl;
    }
    
    // Handle relative paths
    const baseUrlObj = new URL(baseUrl);
    return new URL(relativeUrl, baseUrlObj.href).href;
  }

  /**
   * Follow redirects and get final URL
   */
  async getFinalUrl(url, maxRedirects = 5) {
    try {
      const response = await this.axios.get(url, {
        maxRedirects: maxRedirects,
        validateStatus: function (status) {
          return status >= 200 && status < 400; // Accept redirects
        }
      });
      
      return response.request.res.responseUrl || url;
    } catch (error) {
      console.warn('Could not follow redirects for URL:', url, error.message);
      return url;
    }
  }

  /**
   * Extract domain from URL
   */
  extractDomain(url) {
    try {
      const urlObj = new URL(url);
      return urlObj.hostname;
    } catch (error) {
      console.warn('Could not extract domain from URL:', url);
      return '';
    }
  }

  /**
   * Check if URL is valid
   */
  isValidUrl(url) {
    try {
      new URL(url);
      return true;
    } catch (error) {
      return false;
    }
  }

  /**
   * Site-specific URL cleaning and generation
   */
  generateSiteSpecificUrls(baseUrl, productData, siteKey) {
    switch (siteKey) {
      case 'poppatea':
        return this.generatePoppateaUrls(baseUrl, productData);
      case 'sho-cha':
        return this.generateShoChaUrls(baseUrl, productData);
      case 'matcha-karu':
        return this.generateMatchaKaruUrls(baseUrl, productData);
      default:
        return [this.cleanUrl(baseUrl)];
    }
  }

  generatePoppateaUrls(baseUrl, productData) {
    const urls = [this.cleanUrl(baseUrl)];
    
    // For Poppatea, variants might have different URLs
    if (productData.variants && productData.variants.length > 0) {
      productData.variants.forEach(variant => {
        if (variant.url && variant.url !== baseUrl) {
          urls.push(this.cleanUrl(variant.url));
        }
      });
    }
    
    return urls;
  }

  generateShoChaUrls(baseUrl, productData) {
    // Sho-Cha might need individual product page URLs for price extraction
    return [this.cleanUrl(baseUrl)];
  }

  generateMatchaKaruUrls(baseUrl, productData) {
    // Matcha-Karu URLs are typically clean
    return [this.cleanUrl(baseUrl)];
  }

  /**
   * Extract product ID from URL based on site patterns
   */
  extractProductId(url, siteKey) {
    switch (siteKey) {
      case 'tokichi':
        return this.extractTokichiProductId(url);
      case 'marukyu':
        return this.extractMarukyuProductId(url);
      case 'ippodo':
        return this.extractIppodoProductId(url);
      case 'sho-cha':
        return this.extractShoChaProductId(url);
      case 'poppatea':
        return this.extractPoppateaProductId(url);
      case 'matcha-karu':
        return this.extractMatchaKaruProductId(url);
      case 'yoshien':
        return this.extractYoshienProductId(url);
      case 'sazentea':
        return this.extractSazenteaProductId(url);
      case 'enjoyemeri':
        return this.extractEnjoyemeriProductId(url);
      case 'horiishichimeien':
        return this.extractHoriishichimeienProductId(url);
      default:
        return this.extractGenericProductId(url);
    }
  }

  extractTokichiProductId(url) {
    const match = url.match(/\/products\/([^/?]+)/);
    return match ? match[1] : null;
  }

  extractMarukyuProductId(url) {
    const match = url.match(/\/products\/catalog\/matcha\/([^/?]+)/);
    return match ? match[1] : null;
  }

  extractIppodoProductId(url) {
    const match = url.match(/\/products\/([^/?]+)/);
    return match ? match[1] : null;
  }

  extractShoChaProductId(url) {
    const match = url.match(/\/products\/([^/?]+)/);
    return match ? match[1] : null;
  }

  extractPoppateaProductId(url) {
    const match = url.match(/\/products\/([^/?]+)/);
    return match ? match[1] : null;
  }

  extractMatchaKaruProductId(url) {
    const match = url.match(/\/products\/([^/?]+)/);
    return match ? match[1] : null;
  }

  extractYoshienProductId(url) {
    const match = url.match(/\/products\/([^/?]+)/);
    return match ? match[1] : null;
  }

  extractSazenteaProductId(url) {
    const match = url.match(/\/products\/([^/?]+)/);
    return match ? match[1] : null;
  }

  extractEnjoyemeriProductId(url) {
    const match = url.match(/\/products\/([^/?]+)/);
    return match ? match[1] : null;
  }

  extractHoriishichimeienProductId(url) {
    const match = url.match(/\/products\/([^/?]+)/);
    return match ? match[1] : null;
  }

  extractGenericProductId(url) {
    // Try common patterns
    let match = url.match(/\/products\/([^/?]+)/);
    if (match) return match[1];
    
    match = url.match(/\/product\/([^/?]+)/);
    if (match) return match[1];
    
    match = url.match(/\/item\/([^/?]+)/);
    if (match) return match[1];
    
    // Extract from last path segment
    const pathSegments = url.split('/').filter(segment => segment);
    return pathSegments.length > 0 ? pathSegments[pathSegments.length - 1] : null;
  }

  /**
   * Generate unique product identifier combining site and product info
   */
  generateProductIdentifier(url, title, siteKey) {
    const productId = this.extractProductId(url, siteKey);
    const domain = this.extractDomain(url);
    
    // Create a unique identifier
    if (productId) {
      return `${domain}-${productId}`;
    }
    
    // Fallback: use title-based identifier
    const titleSlug = title.toLowerCase()
      .replace(/[^a-z0-9\s-]/g, '')
      .replace(/\s+/g, '-')
      .substring(0, 50);
    
    return `${domain}-${titleSlug}`;
  }
}

module.exports = URLUtils;
