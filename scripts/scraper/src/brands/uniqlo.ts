import type { BrandScraper, CategoryConfig, RawProduct } from "../types.js";
import { DEFAULT_HEADERS } from "./base.js";

// Uniqlo requires a client ID for their API which we don't have.
// We try to fetch the HTML pages and extract __NEXT_DATA__ or product data.

const CATEGORY_URLS: Record<string, Record<string, string>> = {
  uomo: {
    "t-shirt": "/uomo/top/magliette-e-t-shirt",
    felpe: "/uomo/top/felpe",
    jeans: "/uomo/pantaloni/jeans",
    pantaloni: "/uomo/pantaloni",
    giacche: "/uomo/capispalla",
    camicie: "/uomo/top/camicie",
  },
  donna: {
    "t-shirt": "/donna/top/magliette-e-t-shirt",
    felpe: "/donna/top/felpe",
    jeans: "/donna/pantaloni/jeans",
    pantaloni: "/donna/pantaloni",
    giacche: "/donna/capispalla",
    camicie: "/donna/top/camicie",
  },
};

export class UniqloScraper implements BrandScraper {
  readonly brandSlug = "uniqlo";

  async scrapeCategory(
    category: CategoryConfig,
    gender: "uomo" | "donna",
    limit: number
  ): Promise<RawProduct[]> {
    const path = CATEGORY_URLS[gender]?.[category.slug];
    if (!path) {
      console.log(`  [UNIQLO] No URL mapped for ${gender}/${category.slug}`);
      return [];
    }

    const url = `https://www.uniqlo.com/it/it${path}`;
    console.log(`  [UNIQLO] Fetching: ${url}`);

    let html: string;
    try {
      const resp = await fetch(url, {
        headers: { ...DEFAULT_HEADERS, Accept: "text/html" },
      });
      if (!resp.ok) {
        console.log(`  [UNIQLO] Failed: ${resp.status}`);
        return [];
      }
      html = await resp.text();
    } catch (e: any) {
      console.log(`  [UNIQLO] Error: ${e.message}`);
      return [];
    }

    // Try __NEXT_DATA__
    const nextMatch = html.match(
      /<script id="__NEXT_DATA__"[^>]*>(.*?)<\/script>/s
    );
    if (nextMatch) {
      try {
        const data = JSON.parse(nextMatch[1]);
        return this.extractFromNextData(data, gender, category.slug, limit);
      } catch {
        console.log("  [UNIQLO] Failed to parse __NEXT_DATA__");
      }
    }

    // Try to find product data in HTML
    const products: RawProduct[] = [];
    const jsonLdMatches = html.matchAll(
      /<script type="application\/ld\+json">(.*?)<\/script>/gs
    );
    for (const match of jsonLdMatches) {
      try {
        const ld = JSON.parse(match[1]);
        if (ld["@type"] === "Product" || ld["@type"] === "ItemList") {
          const items = ld.itemListElement || [ld];
          for (const item of items.slice(0, limit)) {
            const product = this.extractFromJsonLd(item, gender, category.slug);
            if (product) products.push(product);
          }
        }
      } catch { /* skip invalid JSON-LD */ }
    }

    if (products.length > 0) {
      console.log(`  [UNIQLO] Found ${products.length} products from JSON-LD`);
    } else {
      console.log("  [UNIQLO] No products found (site may require JavaScript)");
    }

    return products;
  }

  private extractFromNextData(
    data: any,
    gender: "uomo" | "donna",
    category: string,
    limit: number
  ): RawProduct[] {
    const pp = data.props?.pageProps;
    if (!pp) return [];

    const products: RawProduct[] = [];
    const ppStr = JSON.stringify(pp);

    // Look for product arrays in the data
    const productArrayMatch = ppStr.match(/"products":\[(.*?)\]/s);
    if (productArrayMatch) {
      try {
        const items = JSON.parse(`[${productArrayMatch[1]}]`);
        for (const item of items.slice(0, limit)) {
          const product = this.mapUniqloProduct(item, gender, category);
          if (product) products.push(product);
        }
      } catch { /* ignore parse errors */ }
    }

    return products;
  }

  private mapUniqloProduct(
    item: any,
    gender: "uomo" | "donna",
    category: string
  ): RawProduct | null {
    const name = item.name || item.title;
    const price =
      item.price?.current?.value ||
      item.prices?.current?.value ||
      item.price;
    const composition = item.composition || item.material || "";

    if (!name || !price || !composition) return null;

    const imageUrls: string[] = [];
    if (item.images) {
      for (const img of item.images.slice(0, 5)) {
        imageUrls.push(typeof img === "string" ? img : img.url || img.src);
      }
    }

    return {
      name,
      price: typeof price === "number" ? price : parseFloat(price),
      compositionText: composition,
      imageUrls: imageUrls.filter(Boolean),
      productUrl: item.url || item.pdpUrl || "",
      gender,
      category,
    };
  }

  private extractFromJsonLd(
    item: any,
    gender: "uomo" | "donna",
    category: string
  ): RawProduct | null {
    const name = item.name;
    const price = item.offers?.price || item.offers?.lowPrice;
    const material = item.material || "";

    if (!name || !price) return null;

    const imageUrls = Array.isArray(item.image)
      ? item.image.slice(0, 5)
      : item.image
        ? [item.image]
        : [];

    return {
      name,
      price: typeof price === "number" ? price : parseFloat(price),
      compositionText: material,
      imageUrls,
      productUrl: item.url || "",
      gender,
      category,
    };
  }
}
