import { BRANDS, CATEGORIES, loadDbMappings } from "./config.js";
import type { BrandScraper, ScrapeOptions } from "./types.js";
import { processProduct } from "./pipeline/processor.js";
import { insertBatch } from "./pipeline/inserter.js";
import { ZaraScraper } from "./brands/zara.js";
import { HMScraper } from "./brands/hm.js";
import { UniqloScraper } from "./brands/uniqlo.js";
import { COSScraper } from "./brands/cos.js";
import { MassimoDuttiScraper } from "./brands/massimo-dutti.js";

function parseArgs(): ScrapeOptions {
  const args = process.argv.slice(2);
  const options: ScrapeOptions = {
    brands: Object.keys(BRANDS),
    categories: CATEGORIES.map((c) => c.slug),
    genders: ["uomo", "donna"],
    limit: 15,
    dryRun: false,
  };

  for (let i = 0; i < args.length; i++) {
    switch (args[i]) {
      case "--brand":
        options.brands = args[++i].split(",");
        break;
      case "--category":
        options.categories = args[++i].split(",");
        break;
      case "--gender":
        options.genders = args[++i].split(",") as ("uomo" | "donna")[];
        break;
      case "--limit":
        options.limit = parseInt(args[++i], 10);
        break;
      case "--dry-run":
        options.dryRun = true;
        break;
      case "--help":
        printHelp();
        process.exit(0);
    }
  }

  return options;
}

function printHelp(): void {
  console.log(`
Worthy Product Scraper

Usage: npx tsx src/index.ts [options]

Options:
  --brand <slugs>      Comma-separated brand keys (default: all)
                       Available: ${Object.keys(BRANDS).join(", ")}
  --category <slugs>   Comma-separated category slugs (default: all)
                       Available: ${CATEGORIES.map((c) => c.slug).join(", ")}
  --gender <genders>   Comma-separated genders (default: uomo,donna)
  --limit <n>          Max products per category per gender (default: 15)
  --dry-run            Parse and validate only, don't insert into DB
  --help               Show this help

Examples:
  npx tsx src/index.ts --brand zara --category t-shirt --gender uomo --limit 10
  npx tsx src/index.ts --brand hm,cos --limit 20
  npx tsx src/index.ts --dry-run --brand zara --limit 5
`);
}

function createScraper(brandKey: string): BrandScraper | null {
  switch (brandKey) {
    case "zara":
      return new ZaraScraper();
    case "hm":
      return new HMScraper();
    case "uniqlo":
      return new UniqloScraper();
    case "cos":
      return new COSScraper();
    case "massimo-dutti":
      return new MassimoDuttiScraper();
    default:
      console.warn(`No scraper available for: ${brandKey}`);
      return null;
  }
}

async function main(): Promise<void> {
  const options = parseArgs();

  console.log("=== Worthy Product Scraper ===");
  console.log(`Brands: ${options.brands.join(", ")}`);
  console.log(`Categories: ${options.categories.join(", ")}`);
  console.log(`Genders: ${options.genders.join(", ")}`);
  console.log(`Limit: ${options.limit} per category/gender`);
  console.log(`Dry run: ${options.dryRun}`);
  console.log("");

  // Load DB mappings (needed for brand/category ID resolution)
  await loadDbMappings();

  let totalInserted = 0;
  let totalSkipped = 0;
  let totalScraped = 0;

  for (const brandKey of options.brands) {
    const brand = BRANDS[brandKey];
    if (!brand) {
      console.warn(`Unknown brand: ${brandKey}`);
      continue;
    }

    const scraper = createScraper(brandKey);
    if (!scraper) continue;

    console.log(`\n========== ${brand.name} ==========`);

    const categories = CATEGORIES.filter((c) =>
      options.categories.includes(c.slug)
    );

    for (const category of categories) {
      for (const gender of options.genders) {
        console.log(
          `\n--- ${brand.name} > ${category.name} > ${gender} ---`
        );

        try {
          const rawProducts = await scraper.scrapeCategory(
            category,
            gender,
            options.limit
          );

          console.log(`  Scraped ${rawProducts.length} raw products`);
          totalScraped += rawProducts.length;

          // Process products
          const processed = rawProducts
            .map((raw) => processProduct(raw, brand.slug))
            .filter((p) => p !== null);

          console.log(`  ${processed.length} valid after processing`);

          if (options.dryRun) {
            for (const p of processed) {
              console.log(
                `  [DRY] ${p.name} | ${p.price}€ | comp:${p.scoreComposition} | qpr:${p.scoreQpr} | score:${p.worthyScore} | ${p.verdict}`
              );
            }
          } else {
            const { inserted, skipped } = await insertBatch(processed);
            totalInserted += inserted;
            totalSkipped += skipped;
            console.log(`  Inserted: ${inserted}, Skipped: ${skipped}`);
          }
        } catch (e) {
          console.error(
            `  [ERROR] ${brand.name}/${category.slug}/${gender}:`,
            e instanceof Error ? e.message : e
          );
        }
      }
    }
  }

  console.log("\n=== Summary ===");
  console.log(`Total scraped: ${totalScraped}`);
  if (!options.dryRun) {
    console.log(`Total inserted: ${totalInserted}`);
    console.log(`Total skipped: ${totalSkipped}`);
  }
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
