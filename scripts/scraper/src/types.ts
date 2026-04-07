export interface RawProduct {
  name: string;
  price: number;
  compositionText: string;
  imageUrls: string[];
  countryOfProduction?: string;
  productUrl: string;
  gender: "uomo" | "donna" | "unisex";
  category: string;
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
  countryOfProduction: string | null;
  productUrl: string;
  scoreComposition: number;
  scoreQpr: number;
  worthyScore: number;
  verdict: string;
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
