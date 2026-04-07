import { chromium } from "playwright";

async function debugBrands() {
  const browser = await chromium.launch({
    headless: false, // Use headed mode to avoid bot detection
    args: [
      "--disable-blink-features=AutomationControlled",
      "--no-sandbox",
    ],
  });

  const brands = [
    {
      name: "H&M",
      url: "https://www2.hm.com/it_it/uomo/acquista-per-prodotto/magliette.html",
    },
    {
      name: "Uniqlo",
      url: "https://www.uniqlo.com/it/it/uomo/top/t-shirt",
    },
    {
      name: "COS",
      url: "https://www.cos.com/it-it/men/menswear/t-shirts.html",
    },
    {
      name: "Massimo Dutti",
      url: "https://www.massimodutti.com/it/uomo/t-shirt-e-polo-c1861530.html",
    },
    {
      name: "Zara",
      url: "https://www.zara.com/it/it/uomo-magliette-l855.html",
    },
  ];

  for (const brand of brands) {
    const ctx = await browser.newContext({
      locale: "it-IT",
      userAgent:
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
      viewport: { width: 1440, height: 900 },
    });
    const page = await ctx.newPage();

    // Hide automation indicators
    await page.addInitScript(() => {
      Object.defineProperty(navigator, "webdriver", { get: () => false });
    });

    console.log(`\n=== ${brand.name} ===`);
    console.log(`Loading: ${brand.url}`);

    try {
      await page.goto(brand.url, {
        waitUntil: "networkidle",
        timeout: 30000,
      });
      await page.waitForTimeout(3000);

      // Accept cookies
      for (const sel of [
        "#onetrust-accept-btn-handler",
        'button[data-testid="cookie-accept"]',
        'button:has-text("Accetta")',
        'button:has-text("Accept")',
      ]) {
        await page.click(sel).catch(() => {});
      }
      await page.waitForTimeout(1000);

      const title = await page.title();
      const url = page.url();
      console.log(`Title: ${title}`);
      console.log(`Final URL: ${url}`);

      // Count links
      const linkCount = await page.evaluate(
        () => document.querySelectorAll("a").length
      );
      console.log(`Total <a> tags: ${linkCount}`);

      // Find product links
      const links = await page.evaluate(() => {
        return Array.from(document.querySelectorAll("a"))
          .filter((a) => {
            const href = a.href;
            return (
              href.includes(".html") ||
              href.includes("/products/") ||
              href.includes("/productpage/")
            );
          })
          .map((a) => ({
            href: a.href.substring(0, 150),
            cls: a.className.substring(0, 60),
          }));
      });
      console.log(`Product-ish links: ${links.length}`);
      for (const l of links.slice(0, 5)) {
        console.log(`  [${l.cls || "no-class"}] ${l.href}`);
      }

      // Screenshot
      await page.screenshot({
        path: `/tmp/debug-${brand.name.toLowerCase().replace(/[^a-z]/g, "")}.png`,
        fullPage: false,
      });
    } catch (e: any) {
      console.log(`ERROR: ${e.message}`);
    }

    await ctx.close();
  }

  await browser.close();
}

debugBrands().catch(console.error);
