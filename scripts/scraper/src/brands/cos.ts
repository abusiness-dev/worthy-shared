import type { BrandScraper, CategoryConfig, RawProduct } from "../types.js";
import { DEFAULT_HEADERS } from "./base.js";

// COS is part of H&M group and uses a similar Next.js architecture.
// Product detail pages are also protected, so we extract from listings.

const CATEGORY_URLS: Record<string, Record<string, string>> = {
  uomo: {
    "t-shirt": "/it-it/men/menswear/t-shirts-and-vests.html",
    felpe: "/it-it/men/menswear/sweatshirts.html",
    jeans: "/it-it/men/menswear/jeans.html",
    pantaloni: "/it-it/men/menswear/trousers.html",
    giacche: "/it-it/men/menswear/coats-and-jackets.html",
    camicie: "/it-it/men/menswear/shirts.html",
  },
  donna: {
    "t-shirt": "/it-it/women/womenswear/tops/t-shirts.html",
    felpe: "/it-it/women/womenswear/knitwear/sweatshirts.html",
    jeans: "/it-it/women/womenswear/jeans.html",
    pantaloni: "/it-it/women/womenswear/trousers.html",
    giacche: "/it-it/women/womenswear/coats-and-jackets.html",
    camicie: "/it-it/women/womenswear/shirts.html",
  },
};

export class COSScraper implements BrandScraper {
  readonly brandSlug = "cos";

  async scrapeCategory(
    category: CategoryConfig,
    gender: "uomo" | "donna",
    limit: number
  ): Promise<RawProduct[]> {
    const path = CATEGORY_URLS[gender]?.[category.slug];
    if (!path) {
      console.log(`  [COS] No URL mapped for ${gender}/${category.slug}`);
      return [];
    }

    const url = `https://www.cos.com${path}`;
    console.log(`  [COS] Fetching: ${url}`);

    let html: string;
    try {
      const resp = await fetch(url, {
        headers: { ...DEFAULT_HEADERS, Accept: "text/html" },
      });
      if (!resp.ok) {
        console.log(`  [COS] Failed: ${resp.status}`);
        return [];
      }
      html = await resp.text();
    } catch (e: any) {
      console.log(`  [COS] Error: ${e.message}`);
      return [];
    }

    // Extract __NEXT_DATA__
    const nextMatch = html.match(
      /<script id="__NEXT_DATA__"[^>]*>(.*?)<\/script>/s
    );
    if (!nextMatch) {
      console.log("  [COS] No __NEXT_DATA__ found");
      return [];
    }

    const data = JSON.parse(nextMatch[1]);
    const pp = data.props?.pageProps;

    // COS uses a different structure, find product data in blocks or componentProps
    const products: RawProduct[] = [];

    // Search the entire pageProps for product-like data
    const ppStr = JSON.stringify(pp || {});

    // Look for product tiles/cards with articleCode
    const articleMatches = [
      ...ppStr.matchAll(/"articleCode"\s*:\s*"(\d+)"/g),
    ];
    console.log(`  [COS] Found ${articleMatches.length} article codes`);

    // Try to extract product data from blocks
    if (pp?.blocks) {
      for (const block of pp.blocks) {
        const blockStr = JSON.stringify(block);
        if (
          blockStr.includes("product") ||
          blockStr.includes("articleCode")
        ) {
          const items = this.extractProductsFromBlock(block);
          products.push(
            ...items
              .slice(0, limit - products.length)
              .map((item) => this.toRawProduct(item, gender, category.slug))
              .filter((p): p is RawProduct => p !== null)
          );
        }
        if (products.length >= limit) break;
      }
    }

    // If no products from blocks, try fetching individual product pages
    if (products.length === 0 && articleMatches.length > 0) {
      console.log("  [COS] Trying individual product pages...");
      for (const match of articleMatches.slice(0, limit)) {
        try {
          const product = await this.fetchProductByArticle(
            match[1],
            gender,
            category.slug
          );
          if (product) {
            products.push(product);
            console.log(
              `  [COS] ✓ ${product.name} | ${product.price}€ | ${product.compositionText || "no comp"}`
            );
          }
          await new Promise((r) => setTimeout(r, 500 + Math.random() * 1000));
        } catch { /* skip */ }
      }
    }

    console.log(`  [COS] Found ${products.length} products`);
    return products;
  }

  private extractProductsFromBlock(block: any): any[] {
    const items: any[] = [];
    const str = JSON.stringify(block);

    // Try to find product objects
    const productPattern =
      /"title"\s*:\s*"([^"]+)".*?"articleCode"\s*:\s*"(\d+)".*?"price"\s*:\s*"?([^",}]+)"?/g;
    let match;
    while ((match = productPattern.exec(str)) !== null) {
      items.push({
        title: match[1],
        articleCode: match[2],
        price: match[3],
      });
    }

    return items;
  }

  private toRawProduct(
    item: any,
    gender: "uomo" | "donna",
    category: string
  ): RawProduct | null {
    const name = item.title || item.name;
    if (!name) return null;

    const priceStr = String(item.price || "0").replace(/[^0-9,.]/g, "").replace(",", ".");
    const price = parseFloat(priceStr);
    if (!price || price <= 0) return null;

    return {
      name,
      price,
      compositionText: item.composition || item.material || "",
      imageUrls: item.imageUrl ? [item.imageUrl] : [],
      productUrl: item.articleCode
        ? `https://www.cos.com/it-it/product.${item.articleCode}.html`
        : "",
      gender,
      category,
    };
  }

  private async fetchProductByArticle(
    articleCode: string,
    gender: "uomo" | "donna",
    category: string
  ): Promise<RawProduct | null> {
    const url = `https://www.cos.com/it-it/product.${articleCode}.html`;
    try {
      const resp = await fetch(url, {
        headers: { ...DEFAULT_HEADERS, Accept: "text/html" },
      });
      if (!resp.ok) return null;

      const html = await resp.text();
      const nextMatch = html.match(
        /<script id="__NEXT_DATA__"[^>]*>(.*?)<\/script>/s
      );
      if (!nextMatch) return null;

      const data = JSON.parse(nextMatch[1]);
      const ppStr = JSON.stringify(data.props?.pageProps || {});

      // Extract product info
      const nameMatch = ppStr.match(/"name"\s*:\s*"([^"]+)"/);
      const priceMatch = ppStr.match(/"price"\s*:\s*"?(\d+[.,]?\d*)(?:"|,)/);
      const compMatch = ppStr.match(
        /(?:composition|material)['":\s]*['"]([^'"]{5,200})['"]/i
      );
      const imgMatch = ppStr.match(
        /(?:imageUrl|src)['":\s]*['"](https:\/\/[^'"]+\.jpg)['"]/
      );

      const name = nameMatch?.[1];
      const price = priceMatch ? parseFloat(priceMatch[1].replace(",", ".")) : 0;
      const compositionText = compMatch?.[1] || "";

      if (!name || !price) return null;

      return {
        name,
        price,
        compositionText,
        imageUrls: imgMatch ? [imgMatch[1]] : [],
        productUrl: url,
        gender,
        category,
      };
    } catch {
      return null;
    }
  }
}
