import { chromium } from "playwright";

async function debugZara() {
  const browser = await chromium.launch({ headless: true });
  const ctx = await browser.newContext({
    locale: "it-IT",
    userAgent:
      "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
  });
  const page = await ctx.newPage();

  console.log("Loading Zara t-shirt uomo...");
  await page.goto(
    "https://www.zara.com/it/it/uomo-magliette-l855.html",
    { waitUntil: "domcontentloaded", timeout: 30000 }
  );
  await page.waitForTimeout(5000);

  // Accept cookies
  await page.click("#onetrust-accept-btn-handler").catch(() => {
    console.log("No cookie banner");
  });
  await page.waitForTimeout(2000);

  // Scroll
  for (let i = 0; i < 3; i++) {
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
    await page.waitForTimeout(1500);
  }

  // Screenshot
  await page.screenshot({ path: "/tmp/zara-debug.png", fullPage: false });
  console.log("Screenshot saved to /tmp/zara-debug.png");

  // Current URL (check for redirects)
  console.log("Current URL:", page.url());

  // Get all <a> tags
  const allAnchors = await page.evaluate(() => {
    return Array.from(document.querySelectorAll("a")).map((a) => ({
      href: a.href,
      cls: a.className.substring(0, 80),
    }));
  });
  console.log("Total <a> tags:", allAnchors.length);

  // Filter product-like links
  const productLinks = allAnchors.filter(
    (a) => a.href.includes("-p") || a.href.includes("/it/it/") && a.href.includes(".html")
  );
  console.log("Product-like links:", productLinks.length);
  for (const link of productLinks.slice(0, 10)) {
    console.log(" ", link.cls || "(no class)", "→", link.href.substring(0, 120));
  }

  // Find product grid containers
  const containers = await page.evaluate(() => {
    const selectors = [
      "[class*=product]",
      "[class*=Product]",
      "[data-productid]",
      "[class*=grid]",
      "[class*=card]",
      "[class*=item]",
      "li a",
      "article a",
    ];
    const results: Record<string, number> = {};
    for (const sel of selectors) {
      try {
        results[sel] = document.querySelectorAll(sel).length;
      } catch { /* ignore */ }
    }
    return results;
  });
  console.log("\nElement counts by selector:", containers);

  // Page title
  const title = await page.title();
  console.log("Page title:", title);

  // Check for body text
  const bodyText = await page.evaluate(
    () => document.body.innerText.substring(0, 500)
  );
  console.log("\nFirst 500 chars of body text:", bodyText);

  await browser.close();
}

debugZara().catch(console.error);
