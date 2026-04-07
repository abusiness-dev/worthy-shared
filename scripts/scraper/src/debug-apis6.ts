const HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
  Accept: "application/json, text/plain, */*",
  "Accept-Language": "it-IT,it;q=0.9",
};

async function main() {
  // === ZARA: Product detail with real product ID ===
  console.log("=== ZARA: Product detail for real products ===");

  // First get product list
  const listResp = await fetch(
    "https://www.zara.com/it/it/uomo-tshirt-l855.html?ajax=true",
    { headers: HEADERS }
  );
  const listData = await listResp.json();

  // Get real products (skip marketing bundles)
  const products: any[] = [];
  for (const group of listData.productGroups || []) {
    for (const el of group.elements || []) {
      for (const cc of el.commercialComponents || []) {
        if (cc.name && cc.price) products.push(cc);
      }
    }
  }
  console.log(`Real products: ${products.length}`);

  // Test product detail with first 3 products
  for (const p of products.slice(0, 3)) {
    console.log(`\n--- ${p.name} (${p.price / 100}€) ---`);
    const keyword = p.seo?.keyword;
    const id = p.id;

    // Try product page
    const url = `https://www.zara.com/it/it/${keyword}-p${id}.html?ajax=true`;
    console.log(`  Fetching: ${url}`);
    const resp = await fetch(url, { headers: HEADERS });
    console.log(`  Status: ${resp.status}`);

    if (resp.ok) {
      const data = await resp.json();
      const str = JSON.stringify(data);

      // Find composition/materials data
      for (const key of ["rawMaterials", "composition", "care", "detail", "materials"]) {
        if (str.includes(`"${key}"`)) {
          const idx = str.indexOf(`"${key}"`);
          console.log(`  Found "${key}": ${str.substring(idx, idx + 300)}`);
        }
      }

      // Check product.detail.colors
      if (data.product?.detail?.colors) {
        const color = data.product.detail.colors[0];
        if (color) {
          console.log(`  Color keys: ${Object.keys(color).join(", ")}`);
          if (color.rawMaterials) {
            console.log(`  RAW MATERIALS: ${JSON.stringify(color.rawMaterials).substring(0, 500)}`);
          }
          if (color.xmedia) {
            console.log(`  Images: ${color.xmedia.length}`);
            if (color.xmedia[0]?.url) {
              console.log(`  First image: ${color.xmedia[0].url.substring(0, 100)}`);
            }
          }
        }
      }
    } else if (resp.status === 278) {
      const data = await resp.json();
      console.log(`  Redirect: ${data.location}`);
      // Follow redirect
      if (data.location) {
        const rResp = await fetch(data.location, { headers: HEADERS });
        if (rResp.ok) {
          const rData = await rResp.json();
          const rStr = JSON.stringify(rData);
          for (const key of ["rawMaterials", "composition", "care"]) {
            if (rStr.includes(`"${key}"`)) {
              const idx = rStr.indexOf(`"${key}`);
              console.log(`  Found "${key}": ${rStr.substring(idx, idx + 300)}`);
            }
          }
        }
      }
    }
  }

  // Try products-details endpoint with real product IDs
  const ids = products.slice(0, 5).map((p: any) => p.id);
  console.log(`\n=== ZARA: products-details with IDs: ${ids.join(",")} ===`);
  const detResp = await fetch(
    `https://www.zara.com/it/it/products-details?productIds=${ids.join(",")}&ajax=true`,
    { headers: HEADERS }
  );
  if (detResp.ok) {
    const detData = await detResp.json();
    console.log(`Response type: ${Array.isArray(detData) ? 'array' : typeof detData}, length: ${detData.length || Object.keys(detData).length}`);
    if (Array.isArray(detData) && detData.length > 0) {
      const d = detData[0];
      console.log("First detail keys:", Object.keys(d));
      console.log("First detail:", JSON.stringify(d).substring(0, 1000));
    } else if (!Array.isArray(detData)) {
      console.log("Keys:", Object.keys(detData));
      console.log("Preview:", JSON.stringify(detData).substring(0, 500));
    }
  }

  // === H&M: Product detail page ===
  console.log("\n\n=== H&M: Product detail page ===");
  const hmPageUrl = "https://www2.hm.com/it_it/productpage.1336289001.html";
  console.log(`Fetching: ${hmPageUrl}`);
  const hmResp = await fetch(hmPageUrl, { headers: HEADERS });
  console.log(`Status: ${hmResp.status}`);

  if (hmResp.ok) {
    const html = await hmResp.text();
    const nextMatch = html.match(/<script id="__NEXT_DATA__"[^>]*>(.*?)<\/script>/s);
    if (nextMatch) {
      const data = JSON.parse(nextMatch[1]);
      const pp = data.props?.pageProps;
      console.log("Product page pageProps keys:", Object.keys(pp || {}));

      // Look for product data
      if (pp?.productData || pp?.product || pp?.pdp) {
        const pd = pp.productData || pp.product || pp.pdp;
        console.log("Product data keys:", Object.keys(pd));
        console.log("Preview:", JSON.stringify(pd).substring(0, 500));
      }

      // Search for composition in the full data
      const ppStr = JSON.stringify(pp);
      for (const term of ["composition", "composizione", "material", "cotton", "cotone"]) {
        if (ppStr.toLowerCase().includes(term)) {
          const idx = ppStr.toLowerCase().indexOf(term);
          console.log(`\nFound "${term}": ...${ppStr.substring(Math.max(0, idx - 50), idx + 300)}`);
        }
      }
    }
  }
}

main().catch(console.error);
