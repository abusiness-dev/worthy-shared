const HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
  Accept: "application/json, text/plain, */*",
  "Accept-Language": "it-IT,it;q=0.9",
};

async function main() {
  // === ZARA: Explore the categories response ===
  console.log("=== ZARA: Fetching category 855 (magliette uomo) ===");
  const zaraResp = await fetch(
    "https://www.zara.com/it/it/categories?categoryId=855&ajax=true",
    { headers: HEADERS }
  );
  const zaraData = await zaraResp.json();

  // Explore structure
  if (zaraData.categories) {
    const cats = zaraData.categories;
    console.log(`Categories array length: ${cats.length}`);
    if (cats[0]) {
      const cat = cats[0];
      console.log(`First category keys: ${Object.keys(cat).join(", ")}`);
      if (cat.productGroups) {
        console.log(`Product groups: ${cat.productGroups.length}`);
        const firstGroup = cat.productGroups[0];
        if (firstGroup) {
          console.log(`First group keys: ${Object.keys(firstGroup).join(", ")}`);
          if (firstGroup.elements) {
            console.log(`Elements in first group: ${firstGroup.elements.length}`);
            const el = firstGroup.elements[0];
            if (el) {
              console.log(`First element keys: ${Object.keys(el).join(", ")}`);
              if (el.commercialComponents) {
                console.log(`Commercial components: ${el.commercialComponents.length}`);
                const comp = el.commercialComponents[0];
                if (comp) {
                  console.log(`First component keys: ${Object.keys(comp).join(", ")}`);
                  console.log(`Component sample: ${JSON.stringify(comp).substring(0, 500)}`);
                }
              }
            }
          }
        }
      }
    }
  }

  // Now try getting individual product details from Zara
  // Typically at /it/it/product/{productId}/extra-detail?ajax=true
  // Let's find product IDs first
  const productIds: number[] = [];
  if (zaraData.categories?.[0]?.productGroups) {
    for (const group of zaraData.categories[0].productGroups) {
      for (const el of group.elements || []) {
        for (const cc of el.commercialComponents || []) {
          if (cc.id) productIds.push(cc.id);
        }
      }
    }
  }
  console.log(`\nFound ${productIds.length} product IDs`);
  console.log(`Sample IDs: ${productIds.slice(0, 5).join(", ")}`);

  if (productIds.length > 0) {
    console.log(`\n=== ZARA: Fetching product detail ${productIds[0]} ===`);
    const detailResp = await fetch(
      `https://www.zara.com/it/it/product/${productIds[0]}/extra-detail?ajax=true`,
      { headers: HEADERS }
    );
    if (detailResp.ok) {
      const detail = await detailResp.json();
      console.log(`Detail keys: ${Object.keys(detail).join(", ")}`);
      console.log(`Detail sample: ${JSON.stringify(detail).substring(0, 1000)}`);
    } else {
      console.log(`Detail status: ${detailResp.status}`);

      // Try alternative endpoint
      const altResp = await fetch(
        `https://www.zara.com/it/it/products-details?productIds=${productIds[0]}&ajax=true`,
        { headers: HEADERS }
      );
      if (altResp.ok) {
        const alt = await altResp.json();
        console.log(`Alt detail keys: ${Object.keys(alt).join(", ")}`);
        console.log(`Alt detail sample: ${JSON.stringify(alt).substring(0, 1000)}`);
      } else {
        console.log(`Alt detail status: ${altResp.status}`);
      }
    }
  }

  // === H&M: Try different API formats ===
  console.log("\n=== H&M: Testing APIs ===");
  const hmApis = [
    "https://www2.hm.com/it_it/uomo/acquista-per-prodotto/magliette/_jcr_content/main/productlisting.display.json?sort=stock&image-size=small&image=model&offset=0&page-size=36",
    "https://api.hm.com/search-services/v1/it_it/listing/resultpage?pageSource=PLP&page=1&sort=RELEVANCE&pageId=/men/t-shirts-tanks&page-size=36&brand=hm",
  ];

  for (const url of hmApis) {
    try {
      const resp = await fetch(url, { headers: HEADERS });
      const ct = resp.headers.get("content-type") || "";
      console.log(`\nH&M [${resp.status}] ${ct.substring(0, 40)} → ${url.substring(0, 100)}`);
      if (resp.ok) {
        const text = await resp.text();
        if (ct.includes("json")) {
          const json = JSON.parse(text);
          console.log(`Keys: ${Object.keys(json).join(", ")}`);
          console.log(`Preview: ${text.substring(0, 300)}`);
        }
      }
    } catch (e: any) {
      console.log(`H&M ERROR: ${e.message}`);
    }
  }

  // === Uniqlo: Try API ===
  console.log("\n=== Uniqlo: Testing APIs ===");
  const uniqloApis = [
    "https://www.uniqlo.com/it/api/commerce/v5/it/products?path=%2Fit%2Fit%2Fuomo%2Ftop%2Ft-shirt&offset=0&limit=36&httpFailure=true",
    "https://www.uniqlo.com/it/api/commerce/v3/it/products?path=%2Fit%2Fit%2Fuomo%2Ftop%2Ft-shirt&offset=0&limit=36",
    "https://www.uniqlo.com/it/api/commerce/v5/it/products?categoryId=MEN_TSHIRT&offset=0&limit=36",
  ];

  for (const url of uniqloApis) {
    try {
      const resp = await fetch(url, { headers: HEADERS });
      const text = await resp.text();
      console.log(`\nUniqlo [${resp.status}] ${url.substring(60)}`);
      console.log(`Preview: ${text.substring(0, 300)}`);
    } catch (e: any) {
      console.log(`Uniqlo ERROR: ${e.message}`);
    }
  }

  // === COS: Try H&M group API ===
  console.log("\n=== COS: Testing APIs ===");
  const cosApis = [
    "https://www.cos.com/it-it/men/menswear/t-shirts.html",
    "https://www.cos.com/it-it/api/products?path=/men/menswear/t-shirts&page=1&pageSize=36",
  ];

  for (const url of cosApis) {
    try {
      const resp = await fetch(url, { headers: { ...HEADERS, Accept: "text/html,application/json" } });
      console.log(`\nCOS [${resp.status}] ${url.substring(0, 80)}`);
      const text = await resp.text();
      // Check for __NEXT_DATA__
      const nextMatch = text.match(/__NEXT_DATA__.*?({.+?})<\/script>/s);
      if (nextMatch) {
        const data = JSON.parse(nextMatch[1]);
        console.log(`Next.js data keys: ${Object.keys(data).join(", ")}`);
        if (data.props?.pageProps) {
          console.log(`PageProps keys: ${Object.keys(data.props.pageProps).join(", ")}`);
        }
      } else {
        console.log(`Preview: ${text.substring(0, 200)}`);
      }
    } catch (e: any) {
      console.log(`COS ERROR: ${e.message}`);
    }
  }

  // === Massimo Dutti: Try Inditex API (similar to Zara) ===
  console.log("\n=== Massimo Dutti: Testing APIs ===");
  const mdApis = [
    "https://www.massimodutti.com/it/uomo/t-shirt-e-polo-c1861530.html?ajax=true",
    "https://www.massimodutti.com/it/categories?categoryId=1861530&ajax=true",
  ];

  for (const url of mdApis) {
    try {
      const resp = await fetch(url, { headers: HEADERS });
      const ct = resp.headers.get("content-type") || "";
      console.log(`\nMD [${resp.status}] ${ct.substring(0, 40)} → ${url.substring(0, 100)}`);
      if (resp.ok && ct.includes("json")) {
        const json = await resp.json();
        console.log(`Keys: ${Object.keys(json).join(", ")}`);
        console.log(`Preview: ${JSON.stringify(json).substring(0, 300)}`);
      } else if (resp.ok) {
        const text = await resp.text();
        console.log(`Preview: ${text.substring(0, 200)}`);
      }
    } catch (e: any) {
      console.log(`MD ERROR: ${e.message}`);
    }
  }
}

main().catch(console.error);
