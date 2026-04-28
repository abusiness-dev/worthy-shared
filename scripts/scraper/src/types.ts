export interface RawProduct {
  name: string;
  price: number;
  compositionText: string;
  imageUrls: string[];
  countryOfProduction?: string;
  spinningLocation?: string;
  weavingLocation?: string;
  dyeingLocation?: string;
  productUrl: string;
  gender: "uomo" | "donna" | "unisex";
  category: string;
  eanBarcode?: string;
  // Testo libero PDP/etichetta/descrizione per estrazione v2 (tech, cert, origini fibra).
  // Lo scraper può passare qui descrizioni, caratteristiche, label etichetta concatenate.
  rawDescription?: string;
}

export interface ParsedComposition {
  fiber: string;
  percentage: number;
}

export interface ScrapedProduct {
  name: string;
  slug: string;
  brandSlug: string;
  brandId: string;
  categorySlug: string;
  categoryId: string;
  gender: "uomo" | "donna" | "unisex";
  price: number;
  composition: ParsedComposition[];
  photoUrls: string[];
  countryOfProduction: string | null;       // legacy text
  spinningLocation: string | null;
  weavingLocation: string | null;
  dyeingLocation: string | null;
  countryOfProductionIso2: string | null;   // v2 normalized
  spinningIso2: string | null;
  weavingIso2: string | null;
  dyeingIso2: string | null;
  productUrl: string;
  scoreComposition: number;
  scoreQpr: number;
  worthyScore: number;
  verdict: string;
  eanBarcode: string | null;
  // v2 extras (best-effort extraction da rawDescription)
  certifications: string[];
}

export interface BrandScraper {
  readonly brandSlug: string;
  scrapeCategory(
    category: CategoryConfig,
    gender: "uomo" | "donna",
    limit: number
  ): Promise<RawProduct[]>;
}

export interface CategoryConfig {
  slug: string;
  name: string;
}

export interface BrandConfig {
  slug: string;
  name: string;
  baseUrl: string;
}

export interface ScrapeOptions {
  brands: string[];
  categories: string[];
  genders: ("uomo" | "donna")[];
  limit: number;
  dryRun: boolean;
}
