import type { BrandScraper, CategoryConfig, RawProduct } from "../types.js";
import { DEFAULT_HEADERS } from "./base.js";

// Massimo Dutti uses the same Inditex platform as Zara
const CATEGORY_URLS: Record<string, Record<string, string>> = {
  uomo: {
    "t-shirt": "uomo-magliette-polo-l1020051.html",
    felpe: "uomo-felpe-l1020049.html",
    jeans: "uomo-jeans-l1020040.html",
    pantaloni: "uomo-pantaloni-l1020034.html",
    giacche: "uomo-giacche-l1020017.html",
    camicie: "uomo-camicie-casual-l1020045.html",
  },
  donna: {
    "t-shirt": "donna-magliette-l1020229.html",
    felpe: "donna-felpe-l1020227.html",
    jeans: "donna-jeans-l1020218.html",
    pantaloni: "donna-pantaloni-l1020212.html",
    giacche: "donna-giacche-l1020195.html",
    camicie: "donna-camicie-l1020223.html",
  },
};

interface MdCompositionPart {
  description: string;
  components: Array<{ material: string; percentage: string }>;
}

export class MassimoDuttiScraper implements BrandScraper {
  readonly brandSlug = "massimo-dutti";

  async scrapeCategory(
    category: CategoryConfig,
    gender: "uomo" | "donna",
    limit: number
  ): Promise<RawProduct[]> {
    const page = CATEGORY_URLS[gender]?.[category.slug];
    if (!page) {
      console.log(`  [MD] No URL mapped for ${gender}/${category.slug}`);
      return [];
    }

    // Same Inditex API as Zara
    const listUrl = `https://www.massimodutti.com/it/${page}?ajax=true`;
    console.log(`  [MD] Fetching listing: ${listUrl}`);

    let listData: any;
    try {
      const resp = await fetch(listUrl, { headers: DEFAULT_HEADERS });
      if (resp.status === 278) {
        const redir = await resp.json();
        if (redir.location) {
          const resp2 = await fetch(redir.location, { headers: DEFAULT_HEADERS });
          if (!resp2.ok) return [];
          listData = await resp2.json();
        } else {
          return [];
        }
      } else if (!resp.ok) {
        console.log(`  [MD] Listing failed: ${resp.status}`);
        return [];
      } else {
        listData = await resp.json();
      }
    } catch (e: any) {
      console.log(`  [MD] Listing error: ${e.message}`);
      return [];
    }

    // Extract products
    const listingProducts: any[] = [];
    for (const group of listData.productGroups || []) {
      for (const el of group.elements || []) {
        for (const cc of el.commercialComponents || []) {
          if (cc.name && cc.price && cc.seo?.seoProductId) {
            listingProducts.push(cc);
          }
        }
      }
    }

    console.log(`  [MD] Found ${listingProducts.length} products in listing`);
    const selected = listingProducts.slice(0, limit);
    const products: RawProduct[] = [];

    for (const lp of selected) {
      try {
        const product = await this.fetchProductDetail(lp, gender, category.slug);
        if (product) {
          products.push(product);
          console.log(
            `  [MD] ✓ ${product.name} | ${product.price}€ | ${product.compositionText}`
          );
        }
        await new Promise((r) => setTimeout(r, 500 + Math.random() * 1000));
      } catch (e: any) {
        console.warn(`  [MD] ✗ ${lp.name}: ${e.message}`);
      }
    }

    return products;
  }

  private async fetchProductDetail(
    lp: any,
    gender: "uomo" | "donna",
    category: string
  ): Promise<RawProduct | null> {
    const detailUrl = `https://www.massimodutti.com/it/${lp.seo.keyword}-p${lp.seo.seoProductId}.html?ajax=true`;
    let data: any;

    try {
      const resp = await fetch(detailUrl, { headers: DEFAULT_HEADERS });
      if (resp.status === 278) {
        const redir = await resp.json();
        if (redir.location) {
          const resp2 = await fetch(redir.location, { headers: DEFAULT_HEADERS });
          if (!resp2.ok) return null;
          data = await resp2.json();
        } else {
          return null;
        }
      } else if (!resp.ok) {
        return null;
      } else {
        data = await resp.json();
      }
    } catch {
      return null;
    }

    const product = data.product;
    if (!product) return null;

    const name = product.name;
    if (!name) return null;

    const firstColor = product.detail?.colors?.[0];
    const price = (firstColor?.price ?? product.price ?? 0) / 100;
    if (price <= 0) return null;

    // Composition
    const detailedComp = product.detail?.detailedComposition;
    let compositionText = "";
    if (detailedComp?.parts) {
      const mainPart =
        detailedComp.parts.find(
          (p: MdCompositionPart) =>
            p.description === "ESTERNO" || p.description === "TESSUTO PRINCIPALE"
        ) || detailedComp.parts[0];
      if (mainPart?.components) {
        compositionText = mainPart.components
          .map((c: { material: string; percentage: string }) => `${c.percentage} ${c.material}`)
          .join(", ");
      }
    }
    if (!compositionText) return null;

    // Images
    const imageUrls: string[] = [];
    if (firstColor?.xmedia) {
      for (const img of firstColor.xmedia.slice(0, 5)) {
        if (img.path && img.name) {
          imageUrls.push(
            `https://static.massimodutti.net${img.path}${img.name}.jpg?ts=${img.timestamp}&w=750`
          );
        }
      }
    }

    return {
      name,
      price,
      compositionText,
      imageUrls,
      productUrl: detailUrl.replace("?ajax=true", ""),
      gender,
      category,
    };
  }
}
