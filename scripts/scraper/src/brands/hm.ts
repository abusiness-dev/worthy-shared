import type { BrandScraper, CategoryConfig, RawProduct } from "../types.js";
import { DEFAULT_HEADERS } from "./base.js";

// H&M uses Next.js with __NEXT_DATA__ containing product listings
// Product detail pages are blocked (403), so we get what we can from listings
// and try to fetch product detail pages with different strategies

const CATEGORY_URLS: Record<string, Record<string, string>> = {
  uomo: {
    "t-shirt": "/it_it/uomo/acquista-per-prodotto/magliette.html",
    felpe: "/it_it/uomo/acquista-per-prodotto/felpe-e-cardigan.html",
    jeans: "/it_it/uomo/acquista-per-prodotto/jeans.html",
    pantaloni: "/it_it/uomo/acquista-per-prodotto/pantaloni.html",
    giacche: "/it_it/uomo/acquista-per-prodotto/giacche-e-cappotti.html",
    camicie: "/it_it/uomo/acquista-per-prodotto/camicie.html",
  },
  donna: {
    "t-shirt": "/it_it/donna/acquista-per-prodotto/top.html",
    felpe: "/it_it/donna/acquista-per-prodotto/felpe-e-maglioni.html",
    jeans: "/it_it/donna/acquista-per-prodotto/jeans.html",
    pantaloni: "/it_it/donna/acquista-per-prodotto/pantaloni.html",
    giacche: "/it_it/donna/acquista-per-prodotto/giacche-e-cappotti.html",
    camicie: "/it_it/donna/acquista-per-prodotto/camicie-e-bluse.html",
  },
};

export class HMScraper implements BrandScraper {
  readonly brandSlug = "h-and-m";

  async scrapeCategory(
    category: CategoryConfig,
    gender: "uomo" | "donna",
    limit: number
  ): Promise<RawProduct[]> {
    const path = CATEGORY_URLS[gender]?.[category.slug];
    if (!path) {
      console.log(`  [H&M] No URL mapped for ${gender}/${category.slug}`);
      return [];
    }

    const url = `https://www2.hm.com${path}`;
    console.log(`  [H&M] Fetching listing: ${url}`);

    let html: string;
    try {
      const resp = await fetch(url, {
        headers: { ...DEFAULT_HEADERS, Accept: "text/html" },
      });
      if (!resp.ok) {
        console.log(`  [H&M] Listing failed: ${resp.status}`);
        return [];
      }
      html = await resp.text();
    } catch (e: any) {
      console.log(`  [H&M] Listing error: ${e.message}`);
      return [];
    }

    // Extract __NEXT_DATA__
    const nextMatch = html.match(
      /<script id="__NEXT_DATA__"[^>]*>(.*?)<\/script>/s
    );
    if (!nextMatch) {
      console.log("  [H&M] No __NEXT_DATA__ found");
      return [];
    }

    const data = JSON.parse(nextMatch[1]);
    const pp = data.props?.pageProps;

    // Find components with products
    const allProducts: any[] = [];
    for (const comp of pp?.componentProps || []) {
      if (comp.uiProps?.products) {
        allProducts.push(...comp.uiProps.products);
      }
    }

    // Also look for products elsewhere in the data
    const fullStr = JSON.stringify(pp);
    const articleCodes = new Set(allProducts.map((p: any) => p.articleCode));

    // Try to find more products by searching for articleCode patterns
    const articleMatches = fullStr.matchAll(/"articleCode":"(\d+)"/g);
    for (const match of articleMatches) {
      if (!articleCodes.has(match[1])) {
        articleCodes.add(match[1]);
      }
    }

    console.log(`  [H&M] Found ${allProducts.length} products in listing`);

    const selected = allProducts.slice(0, limit);
    const products: RawProduct[] = [];

    for (const lp of selected) {
      try {
        const product = await this.processListingProduct(lp, gender, category.slug);
        if (product) {
          products.push(product);
          console.log(
            `  [H&M] ✓ ${product.name} | ${product.price}€ | ${product.compositionText || "no composition"}`
          );
        }
        await new Promise((r) => setTimeout(r, 300 + Math.random() * 500));
      } catch (e: any) {
        console.warn(`  [H&M] ✗ ${lp.title}: ${e.message}`);
      }
    }

    return products;
  }

  private async processListingProduct(
    lp: any,
    gender: "uomo" | "donna",
    category: string
  ): Promise<RawProduct | null> {
    const name = lp.title;
    if (!name) return null;

    // Price from listing
    const priceText = lp.regularPrice || lp.redPrice || lp.yellowPrice || "";
    const price = parsePrice(priceText);
    if (!price) return null;

    // Images from listing
    const imageUrls: string[] = [];
    if (lp.imageProductSrc) imageUrls.push(lp.imageProductSrc);
    if (lp.imageModelSrc) imageUrls.push(lp.imageModelSrc);
    if (lp.galleryImages) {
      for (const img of lp.galleryImages) {
        if (img.src) imageUrls.push(img.src);
      }
    }

    // Try to get composition from product detail page
    let compositionText = "";
    const pdpUrl = lp.pdpUrl
      ? `https://www2.hm.com${lp.pdpUrl}`
      : lp.articleCode
        ? `https://www2.hm.com/it_it/productpage.${lp.articleCode}.html`
        : null;

    if (pdpUrl) {
      compositionText = await this.fetchComposition(pdpUrl);
    }

    // If no composition found from detail page, skip (composition is required)
    if (!compositionText) {
      return null;
    }

    return {
      name,
      price,
      compositionText,
      imageUrls: imageUrls.slice(0, 5),
      productUrl: pdpUrl || "",
      gender,
      category,
    };
  }

  private async fetchComposition(url: string): Promise<string> {
    try {
      // Try fetching with mobile UA (sometimes less protected)
      const resp = await fetch(url, {
        headers: {
          "User-Agent":
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
          Accept: "text/html",
          "Accept-Language": "it-IT,it;q=0.9",
        },
      });

      if (!resp.ok) return "";

      const html = await resp.text();

      // Look for __NEXT_DATA__ with product details
      const nextMatch = html.match(
        /<script id="__NEXT_DATA__"[^>]*>(.*?)<\/script>/s
      );
      if (nextMatch) {
        const data = JSON.parse(nextMatch[1]);
        const ppStr = JSON.stringify(data.props?.pageProps || {});

        // Find composition patterns
        const compMatch = ppStr.match(
          /(?:"composition"|"materialDescription"|"materials?")[:\s]*"([^"]{5,200})"/i
        );
        if (compMatch) return compMatch[1];

        // Look for percentage patterns in the data
        const pctMatch = ppStr.match(/\d+%\s*[A-Za-zÀ-ÿ]+(?:\s*,\s*\d+%\s*[A-Za-zÀ-ÿ]+)*/);
        if (pctMatch) return pctMatch[0];
      }

      // Search raw HTML for composition
      const htmlCompMatch = html.match(
        /(?:composizione|composition|material)[^<]*?(\d+%\s*[A-Za-zÀ-ÿ]+(?:\s*[,;]\s*\d+%\s*[A-Za-zÀ-ÿ]+)*)/i
      );
      if (htmlCompMatch) return htmlCompMatch[1];
    } catch {
      // Ignore fetch errors
    }
    return "";
  }
}

function parsePrice(text: string): number | null {
  if (!text) return null;
  const cleaned = text.replace(/[^0-9,.]/g, "").replace(",", ".");
  const price = parseFloat(cleaned);
  return isNaN(price) || price <= 0 ? null : price;
}
