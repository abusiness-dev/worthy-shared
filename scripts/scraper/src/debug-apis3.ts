const HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
  Accept: "application/json, text/plain, */*",
  "Accept-Language": "it-IT,it;q=0.9",
};

async function main() {
  // === ZARA: Explore the full category response structure ===
  console.log("=== ZARA: Deep dive into category API ===");
  const zaraResp = await fetch(
    "https://www.zara.com/it/it/categories?categoryId=855&ajax=true",
    { headers: HEADERS }
  );
  const zaraData = await zaraResp.json();

  const firstCat = zaraData.categories[0];
  console.log("Category name:", firstCat.name);
  console.log("Layout keys:", firstCat.layout ? Object.keys(firstCat.layout) : "no layout");

  // Check if layout has products
  if (firstCat.layout) {
    const layout = firstCat.layout;
    console.log("Layout:", JSON.stringify(layout).substring(0, 500));
  }

  // Check subcategories
  if (firstCat.subcategories) {
    console.log("\nSubcategories:", firstCat.subcategories.length);
    for (const sub of firstCat.subcategories.slice(0, 3)) {
      console.log(`  - ${sub.name} (id: ${sub.id})`);
    }
  }

  // For each subcategory that might have products
  for (const cat of zaraData.categories) {
    if (cat.productGroups && cat.productGroups.length > 0) {
      console.log(`\nCategory "${cat.name}" has ${cat.productGroups.length} product groups!`);
      const group = cat.productGroups[0];
      console.log("Group keys:", Object.keys(group));
      if (group.elements) {
        console.log("Elements:", group.elements.length);
        const el = group.elements[0];
        console.log("Element keys:", Object.keys(el));
        console.log("Element sample:", JSON.stringify(el).substring(0, 500));
      }
    }
  }

  // Try fetching the subcategory directly for products
  if (firstCat.subcategories && firstCat.subcategories.length > 0) {
    const subId = firstCat.subcategories[0].id;
    console.log(`\n=== ZARA: Fetching subcategory ${subId} ===`);
    const subResp = await fetch(
      `https://www.zara.com/it/it/categories?categoryId=${subId}&ajax=true`,
      { headers: HEADERS }
    );
    const subData = await subResp.json();
    for (const cat of subData.categories) {
      if (cat.productGroups && cat.productGroups.length > 0) {
        console.log(`Subcategory "${cat.name}" has ${cat.productGroups.length} product groups`);
        for (const g of cat.productGroups) {
          if (g.elements) {
            console.log(`  Group: ${g.elements.length} elements`);
            const el = g.elements[0];
            console.log("  Element keys:", Object.keys(el));
            console.log("  Element:", JSON.stringify(el).substring(0, 800));
          }
        }
      }
    }
  }

  // === ZARA: Try product detail endpoint ===
  // The product IDs might be in a different format
  // Let's try the full page JSON
  console.log("\n=== ZARA: Try page-level product fetch ===");
  const pageResp = await fetch(
    "https://www.zara.com/it/it/uomo-magliette-l855.html?ajax=true",
    { headers: HEADERS }
  );
  if (pageResp.ok) {
    const ct = pageResp.headers.get("content-type") || "";
    console.log("Page response:", pageResp.status, ct);
    const text = await pageResp.text();
    if (ct.includes("json")) {
      const json = JSON.parse(text);
      console.log("Keys:", Object.keys(json));
      console.log("Preview:", JSON.stringify(json).substring(0, 500));
    } else {
      console.log("Not JSON, HTML length:", text.length);
    }
  } else {
    console.log("Page status:", pageResp.status);
  }

  // === H&M: Try their new fabric API ===
  console.log("\n=== H&M: Try fabric/loom API ===");
  const hmUrls = [
    "https://www2.hm.com/hmwebservices/service/product/it/listing/mens_tshirts?page-size=36&currentpage=0&categories=men_tshirtstanks",
    "https://www2.hm.com/it_it/uomo/acquista-per-prodotto/magliette.html",
  ];

  for (const url of hmUrls) {
    try {
      const resp = await fetch(url, { headers: HEADERS });
      const text = await resp.text();
      console.log(`\nH&M [${resp.status}] ${url.substring(0, 80)}`);

      // Look for __NEXT_DATA__ in HTML
      const nextMatch = text.match(/<script id="__NEXT_DATA__"[^>]*>(.*?)<\/script>/s);
      if (nextMatch) {
        const data = JSON.parse(nextMatch[1]);
        console.log("Next.js data found!");
        console.log("Props keys:", Object.keys(data.props?.pageProps || {}));
        const pp = data.props?.pageProps;
        if (pp) {
          // Look for product data
          for (const key of Object.keys(pp)) {
            const val = pp[key];
            if (typeof val === 'object' && val !== null) {
              const str = JSON.stringify(val);
              if (str.includes('product') || str.includes('price') || str.includes('composition')) {
                console.log(`  ${key}: ${str.substring(0, 300)}`);
              }
            }
          }
        }
      }
    } catch (e: any) {
      console.log(`H&M ERROR: ${e.message}`);
    }
  }

  // === Uniqlo: Find the client ID ===
  console.log("\n=== Uniqlo: Find client ID from page ===");
  const uniqloResp = await fetch("https://www.uniqlo.com/it/it/uomo/top/t-shirt", { headers: HEADERS });
  const uniqloHtml = await uniqloResp.text();
  console.log("Uniqlo page status:", uniqloResp.status, "length:", uniqloHtml.length);

  // Look for client ID or API key
  const clientIdMatch = uniqloHtml.match(/client[_-]?id['":\s]*['"]([^'"]+)/i);
  if (clientIdMatch) console.log("Found client ID:", clientIdMatch[1]);

  const apiKeyMatch = uniqloHtml.match(/api[_-]?key['":\s]*['"]([^'"]+)/i);
  if (apiKeyMatch) console.log("Found API key:", apiKeyMatch[1]);

  // Check for NEXT_DATA
  const uniqloNextMatch = uniqloHtml.match(/<script id="__NEXT_DATA__"[^>]*>(.*?)<\/script>/s);
  if (uniqloNextMatch) {
    const data = JSON.parse(uniqloNextMatch[1]);
    console.log("Uniqlo Next.js keys:", Object.keys(data));
    console.log("PageProps keys:", Object.keys(data.props?.pageProps || {}));
    const pp = data.props?.pageProps;
    if (pp?.products) {
      console.log("Products found:", Array.isArray(pp.products) ? pp.products.length : typeof pp.products);
    }
    // Look for any products data
    const str = JSON.stringify(pp || {});
    if (str.includes('"products"')) {
      const pMatch = str.match(/"products":\[/);
      if (pMatch) {
        const idx = str.indexOf('"products":[');
        console.log("Products data found at idx", idx, ":", str.substring(idx, idx + 300));
      }
    }
  }
}

main().catch(console.error);
