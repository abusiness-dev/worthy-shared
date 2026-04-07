import type { BrandScraper, CategoryConfig, RawProduct } from "../types.js";

export const DEFAULT_HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
  Accept: "application/json, text/plain, */*",
  "Accept-Language": "it-IT,it;q=0.9",
};

export abstract class BaseScraper implements BrandScraper {
  abstract readonly brandSlug: string;

  abstract scrapeCategory(
    category: CategoryConfig,
    gender: "uomo" | "donna",
    limit: number
  ): Promise<RawProduct[]>;

  protected delay(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  protected async fetchJson(url: string, headers?: Record<string, string>): Promise<any> {
    const resp = await fetch(url, {
      headers: { ...DEFAULT_HEADERS, ...headers },
    });
    if (!resp.ok) {
      throw new Error(`HTTP ${resp.status} for ${url}`);
    }
    return resp.json();
  }

  protected async fetchHtml(url: string): Promise<string> {
    const resp = await fetch(url, {
      headers: {
        ...DEFAULT_HEADERS,
        Accept: "text/html,application/xhtml+xml",
      },
    });
    if (!resp.ok) {
      throw new Error(`HTTP ${resp.status} for ${url}`);
    }
    return resp.text();
  }
}
