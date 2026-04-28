import { chromium } from "playwright";

const USER_AGENT =
  "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36";

const URL = process.argv[2] ?? "https://www.uniqlo.com/it/it/products/E455365-000/00";

async function main() {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({
    userAgent: USER_AGENT,
    locale: "it-IT",
    viewport: { width: 1366, height: 900 },
  });
  const page = await context.newPage();
  await page.goto(URL, { waitUntil: "domcontentloaded", timeout: 30_000 });
  try {
    await page.waitForLoadState("networkidle", { timeout: 15_000 });
  } catch {
    /* best-effort */
  }
  // scroll per triggerare lazy load
  await page.evaluate(() => window.scrollBy(0, 800));
  await page.waitForTimeout(1500);

  const dump = await page.evaluate(() => {
    const re = /^https?:\/\/[^/]*uniqlo\.com\//i;
    const imgs = Array.from(document.querySelectorAll("img"));
    const rows: any[] = [];
    for (const img of imgs) {
      const src = (img as HTMLImageElement).currentSrc || img.getAttribute("src") || "";
      if (!src || !re.test(src)) continue;
      const alt = img.getAttribute("alt") || "";
      const rect = img.getBoundingClientRect();
      const parent = img.parentElement;
      const parentClass = parent?.className || "";
      const parentTag = parent?.tagName || "";
      const ancestors = [];
      let p: HTMLElement | null = parent;
      for (let i = 0; i < 4 && p; i++) {
        ancestors.push(`${p.tagName}.${(p.className || "").toString().slice(0, 40)}`);
        p = p.parentElement;
      }
      rows.push({
        w: Math.round(rect.width),
        h: Math.round(rect.height),
        alt: alt.slice(0, 60),
        src: src.slice(0, 160),
        parent: `${parentTag}.${parentClass.toString().slice(0, 40)}`,
        ancestors: ancestors.join(" > "),
      });
    }
    return rows;
  });

  console.log(`Found ${dump.length} img elements from uniqlo.com.`);
  for (const r of dump) {
    console.log(
      `  [${String(r.w).padStart(4)}×${String(r.h).padStart(4)}] alt="${r.alt}"`
    );
    console.log(`      src: ${r.src}`);
    console.log(`      parent: ${r.parent}`);
    console.log(`      ancestors: ${r.ancestors}`);
    console.log("");
  }
  await browser.close();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
