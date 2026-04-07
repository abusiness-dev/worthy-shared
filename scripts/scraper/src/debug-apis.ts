// Test direct API access for each brand

const HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
  Accept: "application/json, text/plain, */*",
  "Accept-Language": "it-IT,it;q=0.9,en-US;q=0.8,en;q=0.7",
};

async function tryFetch(name: string, url: string, headers?: Record<string, string>) {
  try {
    const resp = await fetch(url, {
      headers: { ...HEADERS, ...headers },
      redirect: "follow",
    });
    const ct = resp.headers.get("content-type") || "";
    const status = resp.status;
    const text = await resp.text();
    const preview = text.substring(0, 500);
    console.log(`\n=== ${name} ===`);
    console.log(`Status: ${status} | Content-Type: ${ct} | Length: ${text.length}`);

    if (ct.includes("json")) {
      try {
        const json = JSON.parse(text);
        const keys = Object.keys(json);
        console.log(`JSON keys: ${keys.join(", ")}`);
        if (json.products) console.log(`Products: ${json.products.length}`);
        if (json.productListPage) console.log(`Products in PLP: ${JSON.stringify(json.productListPage).substring(0, 200)}`);
        if (json.data) console.log(`Data keys: ${Object.keys(json.data).join(", ")}`);
        if (Array.isArray(json)) console.log(`Array of ${json.length} items`);
      } catch {}
    } else {
      console.log(`Preview: ${preview}`);
    }
  } catch (err: any) {
    console.log(`\n=== ${name} ===`);
    console.log(`ERROR: ${err.message}`);
  }
}

async function main() {
  // Zara - Various API endpoints
  await tryFetch(
    "Zara API v1",
    "https://www.zara.com/it/it/categories?categoryId=855&ajax=true"
  );
  await tryFetch(
    "Zara API v2",
    "https://www.zara.com/it/it/category/855/products?ajax=true"
  );
  await tryFetch(
    "Zara API v3 (new format)",
    "https://www.zara.com/it/rest/searchrecommender/products?categoryId=855&locale=it"
  );

  // H&M API
  await tryFetch(
    "H&M API v1",
    "https://www2.hm.com/it_it/uomo/acquista-per-prodotto/magliette.html",
    { "X-Requested-With": "XMLHttpRequest" }
  );
  await tryFetch(
    "H&M API v2",
    "https://api.hm.com/search-services/v1/it_it/listing/resultpage?pageSource=PLP&page=1&sort=RELEVANCE&pageId=%2Fmen%2Ft-shirts-tanks&page-size=36",
  );

  // Uniqlo API
  await tryFetch(
    "Uniqlo API",
    "https://www.uniqlo.com/it/api/commerce/v3/it/products?path=%2Fit%2Fit%2Fuomo%2Ftop%2Ft-shirt&limit=36&offset=0"
  );
  await tryFetch(
    "Uniqlo API v2",
    "https://www.uniqlo.com/it/api/commerce/v5/it/products?path=/it/it/uomo/top/t-shirt&limit=36&offset=0"
  );

  // COS
  await tryFetch(
    "COS API",
    "https://www.cos.com/it-it/men/menswear/t-shirts.html",
    { "X-Requested-With": "XMLHttpRequest" }
  );

  // Massimo Dutti
  await tryFetch(
    "Massimo Dutti API",
    "https://www.massimodutti.com/itxrest/2/catalog/store/34009400/20309422/category/1861530/product?languageId=-4&showProducts=false&appId=1"
  );
}

main().catch(console.error);
