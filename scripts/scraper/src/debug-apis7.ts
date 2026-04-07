const HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
  Accept: "application/json, text/plain, */*",
  "Accept-Language": "it-IT,it;q=0.9",
};

async function main() {
  // === ZARA: Full product data from listing ===
  console.log("=== ZARA: Full product detail from listing ===");
  const listResp = await fetch(
    "https://www.zara.com/it/it/uomo-tshirt-l855.html?ajax=true",
    { headers: HEADERS }
  );
  const listData = await listResp.json();

  // Get all product data - print FULL first real product
  for (const group of listData.productGroups || []) {
    for (const el of group.elements || []) {
      for (const cc of el.commercialComponents || []) {
        if (!cc.name || !cc.price) continue;
        // Print the FULL product JSON
        console.log("\n=== FULL ZARA PRODUCT ===");
        console.log(JSON.stringify(cc, null, 2).substring(0, 3000));

        // Check all nested keys for materials/composition
        const fullStr = JSON.stringify(cc);
        const interestingTerms = ["material", "composit", "cotton", "polyester", "fiber", "care", "origin", "made in"];
        for (const term of interestingTerms) {
          if (fullStr.toLowerCase().includes(term)) {
            console.log(`  *** Contains "${term}"!`);
          }
        }

        // Check detail.colors for image URLs
        if (cc.detail?.colors?.[0]) {
          const color = cc.detail.colors[0];
          console.log("\n  Color keys:", Object.keys(color));
          if (color.xmedia) {
            console.log(`  Images: ${color.xmedia.length}`);
            const img = color.xmedia[0];
            if (img) {
              console.log("  First image:", JSON.stringify(img).substring(0, 300));
            }
          }
        }

        // Only print first product
        break;
      }
      break;
    }
    break;
  }

  // === ZARA: Try v1 parameter for more data ===
  console.log("\n\n=== ZARA: Try v1 parameter ===");
  const v1Resp = await fetch(
    "https://www.zara.com/it/it/uomo-tshirt-l855.html?v1=2525513&ajax=true",
    { headers: HEADERS }
  );
  if (v1Resp.ok) {
    const v1Data = await v1Resp.json();
    console.log("v1 response keys:", Object.keys(v1Data));
    // Check if products have more detail
    for (const group of v1Data.productGroups || []) {
      for (const el of group.elements || []) {
        for (const cc of el.commercialComponents || []) {
          if (!cc.name || !cc.price) continue;
          const str = JSON.stringify(cc);
          if (str.includes("material") || str.includes("composit")) {
            console.log("PRODUCT WITH MATERIALS:", cc.name);
            console.log(str.substring(0, 500));
          }
          break;
        }
        break;
      }
      break;
    }
  } else {
    console.log("v1 status:", v1Resp.status);
  }

  // === H&M: Try different product endpoints ===
  console.log("\n\n=== H&M: Alternative endpoints ===");
  const hmEndpoints = [
    // New fabric API
    "https://www2.hm.com/it_it/productpage.1336289001.html?ajax=true",
    // API with article code
    "https://www2.hm.com/hmwebservices/service/product/it/it/product/1336289001",
    // Try the graphql endpoint
    "https://api.hm.com/productgql/graphql?query={product(code:\"1336289001\",market:\"it\"){name,compositions{materials{name,percentage}}}}",
  ];

  for (const url of hmEndpoints) {
    try {
      const resp = await fetch(url, { headers: HEADERS });
      console.log(`\nH&M [${resp.status}] ${url.substring(0, 80)}`);
      if (resp.ok) {
        const text = await resp.text();
        const ct = resp.headers.get("content-type") || "";
        if (ct.includes("json")) {
          console.log("JSON:", text.substring(0, 500));
        } else {
          console.log("HTML length:", text.length);
          // Check for composition in HTML
          const compIdx = text.toLowerCase().indexOf("composition");
          if (compIdx > -1) {
            console.log("Composition found at:", compIdx);
            console.log(text.substring(compIdx, compIdx + 200));
          }
        }
      }
    } catch (e: any) {
      console.log(`Error: ${e.message}`);
    }
  }

  // === H&M: Try Loom API (newer backend) ===
  console.log("\n\n=== H&M: Loom API ===");
  const loomResp = await fetch(
    "https://www2.hm.com/content/hmonline/it_it/productpage.1336289001.html/data.json",
    { headers: HEADERS }
  );
  console.log("Loom status:", loomResp.status);
  if (loomResp.ok) {
    const text = await loomResp.text();
    console.log("Preview:", text.substring(0, 500));
  }

  // Try HM product page with "page" query param
  console.log("\n=== H&M: Product page variants ===");
  const hmVariants = [
    "https://www2.hm.com/it_it/productpage.1336289001.html",
    "https://fabric.hmgroup.com/api/product/it_it/1336289001",
  ];
  for (const url of hmVariants) {
    try {
      const resp = await fetch(url, {
        headers: {
          ...HEADERS,
          "Accept": "text/html,application/xhtml+xml",
          "Sec-Fetch-Dest": "document",
          "Sec-Fetch-Mode": "navigate",
          "Sec-Fetch-Site": "none",
          "Sec-Fetch-User": "?1",
          "Cache-Control": "max-age=0",
        },
      });
      console.log(`\n[${resp.status}] ${url.substring(0, 80)}`);
      if (resp.ok) {
        const text = await resp.text();
        // Search for composition data
        const compMatch = text.match(/composizione|composition/i);
        if (compMatch) {
          const idx = text.indexOf(compMatch[0]);
          console.log(`Composition found: ${text.substring(Math.max(0, idx - 50), idx + 300)}`);
        }
        // Search for __NEXT_DATA__
        const nextMatch = text.match(/<script id="__NEXT_DATA__"[^>]*>(.*?)<\/script>/s);
        if (nextMatch) {
          const data = JSON.parse(nextMatch[1]);
          const pp = data.props?.pageProps;
          console.log("pageProps keys:", Object.keys(pp || {}));
          // Look for product/material data in all keys
          for (const key of Object.keys(pp || {})) {
            const val = JSON.stringify(pp[key]);
            if (val.toLowerCase().includes("cotton") || val.toLowerCase().includes("cotone") || val.toLowerCase().includes("composit")) {
              console.log(`  Key "${key}" has material data: ${val.substring(0, 300)}`);
            }
          }
        }
      }
    } catch (e: any) {
      console.log(`Error: ${e.message}`);
    }
  }
}

main().catch(console.error);
