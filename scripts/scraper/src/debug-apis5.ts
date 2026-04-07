const HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
  Accept: "application/json, text/plain, */*",
  "Accept-Language": "it-IT,it;q=0.9",
};

async function main() {
  // === ZARA: Get product details from category page ===
  console.log("=== ZARA: Product listing ===");
  const zaraResp = await fetch(
    "https://www.zara.com/it/it/uomo-tshirt-l855.html?ajax=true",
    { headers: HEADERS }
  );
  const zaraData = await zaraResp.json();

  console.log("productGroups count:", zaraData.productGroups?.length);

  // Extract products from productGroups
  const zaraProducts: any[] = [];
  for (const group of zaraData.productGroups || []) {
    for (const el of group.elements || []) {
      for (const cc of el.commercialComponents || []) {
        zaraProducts.push(cc);
      }
    }
  }

  console.log(`Total products: ${zaraProducts.length}`);
  if (zaraProducts.length > 0) {
    const p = zaraProducts[0];
    console.log("\nFirst product keys:", Object.keys(p));
    console.log("Product sample:", JSON.stringify(p).substring(0, 1500));
  }

  // Get a few more product samples
  for (const p of zaraProducts.slice(0, 3)) {
    console.log(`\n--- ${p.name || p.commercialName || 'unknown'} ---`);
    console.log(`  id: ${p.id}`);
    console.log(`  name: ${p.name}`);
    console.log(`  seo.keyword: ${p.seo?.keyword}`);
    console.log(`  price: ${JSON.stringify(p.price)}`);

    // Check for detail/composition
    if (p.detail) console.log(`  detail keys: ${Object.keys(p.detail)}`);
    if (p.extraInfo) console.log(`  extraInfo: ${JSON.stringify(p.extraInfo).substring(0, 200)}`);
    if (p.xmedia) console.log(`  xmedia (images): ${p.xmedia?.length || 0}`);
    if (p.colorInfo) console.log(`  colorInfo: ${JSON.stringify(p.colorInfo).substring(0, 200)}`);
  }

  // Fetch individual product detail for composition
  if (zaraProducts.length > 0) {
    const productId = zaraProducts[0].id;
    const seoKeyword = zaraProducts[0].seo?.keyword;
    console.log(`\n=== ZARA: Product detail for ${productId} ===`);

    const detailUrls = [
      `https://www.zara.com/it/it/${seoKeyword || 'product'}-p${productId}.html?ajax=true`,
      `https://www.zara.com/it/it/products-details?productIds=${productId}&ajax=true`,
    ];

    for (const url of detailUrls) {
      try {
        const resp = await fetch(url, { headers: HEADERS });
        console.log(`\n[${resp.status}] ${url.substring(0, 100)}`);
        if (resp.ok) {
          const text = await resp.text();
          const ct = resp.headers.get("content-type") || "";
          if (ct.includes("json")) {
            const json = JSON.parse(text);
            console.log("Keys:", Object.keys(json));
            // Look for composition/materials
            const str = JSON.stringify(json);
            if (str.includes("composición") || str.includes("composizione") || str.includes("composition") || str.includes("material")) {
              console.log("COMPOSITION FOUND!");
              // Find it
              for (const pattern of [/"composicion"/, /"composition"/, /"material"/, /"care"/]) {
                const match = str.match(pattern);
                if (match) {
                  const idx = str.indexOf(match[0]);
                  console.log(`  ${pattern}: ...${str.substring(idx, idx + 400)}`);
                }
              }
            }
            // Look for product detail
            if (json.product) {
              console.log("Product keys:", Object.keys(json.product));
              if (json.product.detail) console.log("Detail:", JSON.stringify(json.product.detail).substring(0, 500));
            }
            console.log("Full preview:", text.substring(0, 1000));
          }
        }
      } catch (e: any) {
        console.log(`Error: ${e.message}`);
      }
    }
  }

  // === H&M: Extract individual product data ===
  console.log("\n\n=== H&M: Product details ===");
  const hmResp = await fetch(
    "https://www2.hm.com/it_it/uomo/acquista-per-prodotto/magliette.html",
    { headers: HEADERS }
  );
  const hmHtml = await hmResp.text();
  const hmNextMatch = hmHtml.match(/<script id="__NEXT_DATA__"[^>]*>(.*?)<\/script>/s);
  if (hmNextMatch) {
    const data = JSON.parse(hmNextMatch[1]);
    const pp = data.props?.pageProps;
    const componentWithProducts = pp?.componentProps?.find(
      (c: any) => c.uiProps?.products?.length > 0
    );
    if (componentWithProducts) {
      const products = componentWithProducts.uiProps.products;
      console.log(`Found ${products.length} products`);
      if (products.length > 0) {
        console.log("\nFirst product keys:", Object.keys(products[0]));
        console.log("First product:", JSON.stringify(products[0]).substring(0, 800));
      }
      for (const p of products.slice(0, 3)) {
        console.log(`\n--- ${p.title || p.name || 'unknown'} ---`);
        console.log(`  price: ${p.price || p.originalPrice}`);
        console.log(`  articleCode: ${p.articleCode}`);
        console.log(`  url: ${p.url || p.href}`);
      }

      // Try to fetch individual product for composition
      if (products[0]?.url || products[0]?.articleCode) {
        const artCode = products[0].articleCode;
        const prodUrl = products[0].url;
        console.log(`\n=== H&M: Product detail ===`);

        // Try product page
        if (prodUrl) {
          const fullUrl = prodUrl.startsWith("http")
            ? prodUrl
            : `https://www2.hm.com${prodUrl}`;
          console.log(`Fetching: ${fullUrl}`);
          const detResp = await fetch(fullUrl, { headers: HEADERS });
          const detHtml = await detResp.text();

          const detNext = detHtml.match(/<script id="__NEXT_DATA__"[^>]*>(.*?)<\/script>/s);
          if (detNext) {
            const detData = JSON.parse(detNext[1]);
            const detPP = detData.props?.pageProps;
            console.log("Product page pageProps keys:", Object.keys(detPP || {}));

            // Look for composition
            const detStr = JSON.stringify(detPP);
            for (const term of ["composition", "composizione", "material", "cotton", "cotone", "polyester"]) {
              if (detStr.toLowerCase().includes(term)) {
                const idx = detStr.toLowerCase().indexOf(term);
                console.log(`  Found "${term}" at ${idx}: ...${detStr.substring(Math.max(0, idx - 50), idx + 200)}`);
                break;
              }
            }
          }
        }
      }
    }
  }
}

main().catch(console.error);
