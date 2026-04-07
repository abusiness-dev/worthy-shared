import type { BrandScraper, CategoryConfig, RawProduct } from "../types.js";

const HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
  Accept: "application/json, text/plain, */*",
  "Accept-Language": "it-IT,it;q=0.9",
};

// Zara category page URLs (IT site) — verified working as of 2026-03
const CATEGORY_URLS: Record<string, Record<string, string>> = {
  uomo: {
    "t-shirt": "uomo-tshirt-l855.html",
    felpe: "uomo-felpe-l837.html",
    jeans: "uomo-jeans-l838.html",
    pantaloni: "uomo-pantaloni-l836.html",
    giacche: "uomo-giacche-l839.html",
    camicie: "uomo-camicie-l872.html",
  },
  donna: {
    "t-shirt": "donna-tshirt-l1362.html",
    felpe: "donna-felpe-l1330.html",
    jeans: "donna-jeans-l1119.html",
    pantaloni: "donna-pantaloni-l1335.html",
    giacche: "donna-giubbotti-l1114.html",
    camicie: "donna-camicie-l1217.html",
  },
};

interface ZaraListingProduct {
  id: number;
  name: string;
  price: number;
  seo: { keyword: string; seoProductId: string };
  sectionName: string;
  familyName: string;
  detail: {
    colors: Array<{
      xmedia: Array<{ path: string; name: string; timestamp: string }>;
    }>;
  };
}

interface ZaraCompositionPart {
  description: string;
  components: Array<{ material: string; percentage: string }>;
}

export class ZaraScraper implements BrandScraper {
  readonly brandSlug = "zara";

  async scrapeCategory(
    category: CategoryConfig,
    gender: "uomo" | "donna",
    limit: number
  ): Promise<RawProduct[]> {
    const page = CATEGORY_URLS[gender]?.[category.slug];
    if (!page) {
      console.log(`  [ZARA] No URL mapped for ${gender}/${category.slug}`);
      return [];
    }

    // Step 1: Get product listing
    const listUrl = `https://www.zara.com/it/it/${page}?ajax=true`;
    console.log(`  [ZARA] Fetching listing: ${listUrl}`);

    let listData: any;
    const listResp = await fetch(listUrl, { headers: HEADERS });
    if (listResp.status === 278) {
      // Follow Inditex-style redirect
      const redir = await listResp.json();
      if (redir.location) {
        console.log(`  [ZARA] Following redirect → ${redir.location.split('/it/it/')[1]?.split('?')[0] || redir.location}`);
        const resp2 = await fetch(redir.location, { headers: HEADERS });
        if (!resp2.ok) return [];
        listData = await resp2.json();
      } else {
        return [];
      }
    } else if (!listResp.ok) {
      console.log(`  [ZARA] Listing failed: ${listResp.status}`);
      return [];
    } else {
      listData = await listResp.json();
    }

    // Extract products from productGroups
    const listingProducts: ZaraListingProduct[] = [];
    for (const group of listData.productGroups || []) {
      for (const el of group.elements || []) {
        for (const cc of el.commercialComponents || []) {
          if (cc.name && cc.price && cc.seo?.seoProductId) {
            listingProducts.push(cc);
          }
        }
      }
    }

    console.log(`  [ZARA] Found ${listingProducts.length} products in listing`);
    const selected = listingProducts.slice(0, limit);

    // Step 2: Fetch detail for each product (composition + images)
    const products: RawProduct[] = [];
    for (const lp of selected) {
      try {
        const product = await this.fetchProductDetail(lp, gender, category.slug);
        if (product) {
          products.push(product);
          console.log(
            `  [ZARA] ✓ ${product.name} | ${product.price}€ | ${product.compositionText}`
          );
        }
        // Rate limiting
        await new Promise((r) => setTimeout(r, 500 + Math.random() * 1000));
      } catch (e: any) {
        console.warn(`  [ZARA] ✗ ${lp.name}: ${e.message}`);
      }
    }

    return products;
  }

  private async fetchProductDetail(
    lp: ZaraListingProduct,
    gender: "uomo" | "donna",
    category: string
  ): Promise<RawProduct | null> {
    const detailUrl = `https://www.zara.com/it/it/${lp.seo.keyword}-p${lp.seo.seoProductId}.html?ajax=true`;
    const resp = await fetch(detailUrl, { headers: HEADERS });

    if (!resp.ok) {
      // Try following redirect for 278 responses
      if (resp.status === 278) {
        const body = await resp.json();
        if (body.location) {
          const redirectResp = await fetch(body.location, { headers: HEADERS });
          if (!redirectResp.ok) return null;
          return this.parseProductDetail(await redirectResp.json(), gender, category, detailUrl);
        }
      }
      return null;
    }

    const data = await resp.json();
    return this.parseProductDetail(data, gender, category, detailUrl);
  }

  private parseProductDetail(
    data: any,
    gender: "uomo" | "donna",
    category: string,
    url: string
  ): RawProduct | null {
    const product = data.product;
    if (!product) return null;

    const name = product.name;
    if (!name) return null;

    // Price from first color (in cents)
    const firstColor = product.detail?.colors?.[0];
    const price = (firstColor?.price ?? product.price ?? 0) / 100;
    if (price <= 0) return null;

    // Composition from detailedComposition
    const detailedComp = product.detail?.detailedComposition;
    let compositionText = "";
    if (detailedComp?.parts) {
      // Take the main part (ESTERNO / outer) or first part
      const mainPart =
        detailedComp.parts.find(
          (p: ZaraCompositionPart) =>
            p.description === "ESTERNO" || p.description === "TESSUTO PRINCIPALE"
        ) || detailedComp.parts[0];

      if (mainPart?.components) {
        compositionText = mainPart.components
          .map((c: { material: string; percentage: string }) => `${c.percentage} ${c.material}`)
          .join(", ");
      }
    }
    if (!compositionText) return null;

    // Images from first color xmedia
    const imageUrls: string[] = [];
    if (firstColor?.xmedia) {
      for (const img of firstColor.xmedia.slice(0, 5)) {
        if (img.url) {
          // Use the url field and replace {width} placeholder
          imageUrls.push(img.url.replace("{width}", "750"));
        } else if (img.path && img.name) {
          // Fallback: construct URL as path/name/name.jpg
          imageUrls.push(
            `https://static.zara.net${img.path}/${img.name}.jpg?ts=${img.timestamp}&w=750`
          );
        }
      }
    }

    // Country of production (not available in Zara API)
    const countryOfProduction = undefined;

    return {
      name,
      price,
      compositionText,
      imageUrls,
      countryOfProduction,
      productUrl: url.replace("?ajax=true", ""),
      gender,
      category,
    };
  }
}
