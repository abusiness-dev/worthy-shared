const HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
  Accept: "application/json, text/plain, */*",
  "Accept-Language": "it-IT,it;q=0.9",
};

async function main() {
  // === H&M: Extract product data from __NEXT_DATA__ ===
  console.log("=== H&M: Extracting product data ===");
  const hmResp = await fetch(
    "https://www2.hm.com/it_it/uomo/acquista-per-prodotto/magliette.html",
    { headers: HEADERS }
  );
  const hmHtml = await hmResp.text();
  const hmNextMatch = hmHtml.match(/<script id="__NEXT_DATA__"[^>]*>(.*?)<\/script>/s);
  if (hmNextMatch) {
    const data = JSON.parse(hmNextMatch[1]);
    const pp = data.props?.pageProps;

    // Explore pageData
    if (pp?.pageData) {
      console.log("pageData keys:", Object.keys(pp.pageData));
      console.log("pageData:", JSON.stringify(pp.pageData).substring(0, 500));
    }

    // Explore componentProps more deeply
    if (pp?.componentProps) {
      console.log("\ncomponentProps length:", pp.componentProps.length);
      for (let i = 0; i < Math.min(pp.componentProps.length, 5); i++) {
        const comp = pp.componentProps[i];
        const keys = Object.keys(comp);
        console.log(`\n  [${i}] keys: ${keys.join(", ")}`);
        if (comp.productList || comp.products || comp.items) {
          console.log(`  HAS PRODUCTS!`);
          const products = comp.productList || comp.products || comp.items;
          console.log(`  Products: ${JSON.stringify(products).substring(0, 500)}`);
        }
        if (comp.uiProps?.products) {
          console.log(`  Products in uiProps!`);
        }
        // Check for product data nested somewhere
        const str = JSON.stringify(comp);
        if (str.includes('"articleCode"') || str.includes('"productCode"') || str.includes('"price"')) {
          console.log(`  Contains product-like data!`);
          // Find the key with products
          for (const key of keys) {
            const keyStr = JSON.stringify(comp[key]);
            if (keyStr.includes('"articleCode"') || keyStr.includes('"price"')) {
              console.log(`    Key "${key}": ${keyStr.substring(0, 400)}`);
            }
          }
        }
      }
    }

    // Look for products in the entire pageProps
    const ppStr = JSON.stringify(pp);
    if (ppStr.includes('"articleCode"') || ppStr.includes('"productId"')) {
      // Find where products live
      const idx = ppStr.indexOf('"articleCode"');
      if (idx > -1) {
        console.log("\narticleCode found at index", idx);
        console.log("Context:", ppStr.substring(Math.max(0, idx - 100), idx + 200));
      }
    }
  }

  // === ZARA: Follow redirect and try the correct URL ===
  console.log("\n\n=== ZARA: Follow redirected URL ===");
  const zaraResp = await fetch(
    "https://www.zara.com/it/it/uomo-tshirt-l855.html?ajax=true",
    { headers: HEADERS, redirect: "follow" }
  );
  console.log("Zara status:", zaraResp.status);
  const zaraCt = zaraResp.headers.get("content-type");
  console.log("Content-type:", zaraCt);
  if (zaraResp.ok) {
    const text = await zaraResp.text();
    if (zaraCt?.includes("json")) {
      const json = JSON.parse(text);
      console.log("Keys:", Object.keys(json));
      console.log("Preview:", text.substring(0, 500));
    } else {
      console.log("HTML length:", text.length);
      // Check for product data in HTML
      const nextMatch = text.match(/__NEXT_DATA__.*?({.+?})<\/script>/s);
      if (nextMatch) console.log("Found Next.js data");
      // Check for window.__INITIAL_STATE__
      const stateMatch = text.match(/window\.__INITIAL_STATE__\s*=\s*({.+?});/s);
      if (stateMatch) {
        console.log("Found __INITIAL_STATE__");
        console.log(stateMatch[1].substring(0, 500));
      }
      // Check for product JSON in HTML
      const prodMatch = text.match(/(?:"products?"|"productList"|"items"):\[/);
      if (prodMatch) {
        const idx = text.indexOf(prodMatch[0]);
        console.log("Product data found in HTML at idx", idx);
        console.log(text.substring(idx, idx + 500));
      }
    }
  }

  // Try Zara products-details endpoint with various formats
  console.log("\n=== ZARA: Products endpoints ===");
  const zaraEndpoints = [
    "https://www.zara.com/it/it/category/855/products?ajax=true",
    "https://www.zara.com/it/it/categories?ajax=true",
    "https://www.zara.com/it/it/man-tshirts-l855.html?v1=2525513&ajax=true",
  ];
  for (const url of zaraEndpoints) {
    const resp = await fetch(url, { headers: HEADERS });
    console.log(`\n[${resp.status}] ${url.substring(0, 80)}`);
    if (resp.ok) {
      const text = await resp.text();
      console.log(`Length: ${text.length}, Preview: ${text.substring(0, 200)}`);
    }
  }

  // === UNIQLO: Try correct Italian URLs ===
  console.log("\n\n=== UNIQLO: Find correct URLs ===");
  // First get the main page to find navigation structure
  const uniqloResp = await fetch("https://www.uniqlo.com/it/it/uomo.html", {
    headers: HEADERS,
  });
  console.log("Uniqlo main:", uniqloResp.status);
  if (uniqloResp.ok) {
    const html = await uniqloResp.text();
    // Find t-shirt links
    const links = [...html.matchAll(/href="([^"]*(?:t-shirt|tshirt|magliett)[^"]*)"/gi)];
    console.log("T-shirt links:", links.map(m => m[1]).slice(0, 5));

    // Find API client ID
    const clientMatch = html.match(/clientId['":\s]*['"]([\w-]+)['"]/);
    if (clientMatch) console.log("Client ID:", clientMatch[1]);
  }
}

main().catch(console.error);
