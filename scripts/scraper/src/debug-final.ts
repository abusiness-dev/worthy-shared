const HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
  Accept: "application/json, text/plain, */*",
  "Accept-Language": "it-IT,it;q=0.9",
};

async function main() {
  // === ZARA: Print full product JSON for the second product (skip bundles) ===
  console.log("=== ZARA: Full product dump ===");
  const listResp = await fetch(
    "https://www.zara.com/it/it/uomo-tshirt-l855.html?ajax=true",
    { headers: HEADERS }
  );
  const listData = await listResp.json();

  let count = 0;
  for (const group of listData.productGroups || []) {
    for (const el of group.elements || []) {
      for (const cc of el.commercialComponents || []) {
        if (!cc.name || !cc.price) continue;
        count++;
        if (count <= 2) {
          console.log(`\n=== Product ${count}: ${cc.name} ===`);
          // Print ALL keys and their types/values
          for (const key of Object.keys(cc)) {
            const val = cc[key];
            if (typeof val === "object" && val !== null) {
              const str = JSON.stringify(val);
              console.log(`  ${key} (${Array.isArray(val) ? 'array:' + val.length : 'object'}): ${str.substring(0, 200)}`);
            } else {
              console.log(`  ${key}: ${val}`);
            }
          }

          // Try serverPage path as URL
          if (cc.serverPage) {
            console.log(`\n  Trying serverPage: ${cc.serverPage}`);
            const url = `https://www.zara.com${cc.serverPage}?ajax=true`;
            const resp = await fetch(url, { headers: HEADERS });
            console.log(`  Status: ${resp.status}`);
            if (resp.ok) {
              const data = await resp.json();
              const str = JSON.stringify(data);
              console.log(`  Response length: ${str.length}`);
              // Check for rawMaterials
              if (str.includes("rawMaterials")) {
                const idx = str.indexOf("rawMaterials");
                console.log(`  RAW MATERIALS: ${str.substring(idx, idx + 500)}`);
              }
              if (str.includes("detail")) {
                console.log(`  Has "detail" key`);
                if (data.product?.detail) {
                  console.log(`  Product detail keys: ${Object.keys(data.product.detail)}`);
                }
              }
              // Print keys
              console.log(`  Response keys: ${Object.keys(data).join(", ")}`);
            }
          }

          // Try the seo.productUrl or similar
          if (cc.seo) {
            console.log(`\n  SEO data: ${JSON.stringify(cc.seo)}`);
          }
        }
        if (count === 2) break;
      }
      if (count === 2) break;
    }
    if (count === 2) break;
  }

  console.log(`\nTotal real products in listing: ${count}`);

  // Print product 10-12 as additional samples
  console.log("\n=== More product samples ===");
  count = 0;
  for (const group of listData.productGroups || []) {
    for (const el of group.elements || []) {
      for (const cc of el.commercialComponents || []) {
        if (!cc.name || !cc.price) continue;
        count++;
        if (count >= 10 && count <= 12) {
          console.log(`${count}. ${cc.name} - ${cc.price / 100}EUR - colors: ${cc.detail?.colors?.length || 0}`);
          // Check detail.colors for images and materials
          if (cc.detail?.colors?.[0]) {
            const c = cc.detail.colors[0];
            console.log(`   Color keys: ${Object.keys(c).join(", ")}`);
            if (c.xmedia?.length) {
              const img = c.xmedia[0];
              console.log(`   Image URL pattern: ${img.path || img.url || "no url"}`);
            }
          }
        }
      }
    }
  }

  // === H&M: Parse old HTML for composition ===
  console.log("\n\n=== H&M: Old HTML product page ===");
  const hmOldResp = await fetch(
    "https://www2.hm.com/content/hmonline/it_it/productpage.1336289001.html/data.json",
    { headers: HEADERS }
  );
  if (hmOldResp.ok) {
    const html = await hmOldResp.text();
    console.log(`HTML length: ${html.length}`);

    // Search for composition-related content
    const patterns = [
      /composizione[^<]{0,500}/gi,
      /composition[^<]{0,500}/gi,
      /material[^<]{0,300}/gi,
      /\d+%\s*[A-Za-zÀ-ÿ]+/g,
      /cotton|cotone|polyester|poliestere|elastane|elastan/gi,
    ];
    for (const pat of patterns) {
      const matches = html.match(pat);
      if (matches) {
        console.log(`\nPattern ${pat.source}: ${matches.length} matches`);
        for (const m of matches.slice(0, 3)) {
          console.log(`  "${m.substring(0, 100)}"`);
        }
      }
    }
  }

  // === H&M: Try fetching product page SSR HTML ===
  console.log("\n\n=== H&M: Try with different Accept headers ===");
  const hmProdResp = await fetch(
    "https://www2.hm.com/it_it/productpage.1336289001.html",
    {
      headers: {
        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
        Accept: "text/html,application/xhtml+xml,application/xml;q=0.9",
        "Accept-Language": "it-IT,it;q=0.9",
        "Sec-Fetch-Dest": "document",
        "Sec-Fetch-Mode": "navigate",
        "Sec-Fetch-Site": "none",
      },
    }
  );
  console.log(`H&M mobile UA: ${hmProdResp.status}`);
  if (hmProdResp.ok) {
    const html = await hmProdResp.text();
    console.log(`Length: ${html.length}`);
    // Find composition
    const compMatch = html.match(/composizione|composition/i);
    if (compMatch) {
      const idx = html.indexOf(compMatch[0]);
      console.log(`Found at ${idx}: ${html.substring(Math.max(0, idx - 50), idx + 300)}`);
    }
  }
}

main().catch(console.error);
