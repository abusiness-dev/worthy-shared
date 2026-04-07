import { supabase } from "./config.js";

const HEADERS = {
  "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
  Accept: "application/json",
  "Accept-Language": "it-IT,it;q=0.9",
};

function extractSeoInfo(url: string): { keyword: string; seoId: string } | null {
  const match = url.match(/\/it\/it\/(.+)-p(\d+)\.html/);
  return match ? { keyword: match[1], seoId: match[2] } : null;
}

async function fixImages() {
  const { data: products } = await supabase
    .from("products")
    .select("id, name, affiliate_url");

  if (!products?.length) {
    console.log("No products found");
    return;
  }

  // Group by seoId to avoid duplicate API calls
  const seoMap = new Map<string, { keyword: string; ids: string[] }>();
  for (const p of products) {
    const info = extractSeoInfo(p.affiliate_url || "");
    if (info) {
      if (!seoMap.has(info.seoId)) {
        seoMap.set(info.seoId, { keyword: info.keyword, ids: [] });
      }
      seoMap.get(info.seoId)!.ids.push(p.id);
    }
  }

  console.log(`Fixing images for ${products.length} products (${seoMap.size} unique seoIds)...\n`);

  let fixed = 0;
  let failed = 0;
  let checked = 0;

  for (const [seoId, { keyword, ids }] of seoMap) {
    checked++;
    try {
      const url = `https://www.zara.com/it/it/${keyword}-p${seoId}.html?ajax=true`;
      let data: any;

      const resp = await fetch(url, { headers: HEADERS });
      if (resp.status === 278) {
        const redir = await resp.json();
        if (redir.location) {
          const r2 = await fetch(redir.location, { headers: HEADERS });
          if (r2.ok) data = await r2.json();
        }
      } else if (resp.ok) {
        data = await resp.json();
      }

      if (!data?.product?.detail?.colors?.[0]?.xmedia) {
        failed += ids.length;
        continue;
      }

      const xmedia = data.product.detail.colors[0].xmedia;
      const imageUrls: string[] = [];
      for (const img of xmedia.slice(0, 5)) {
        if (img.url) {
          imageUrls.push(img.url.replace("{width}", "750"));
        }
      }

      if (imageUrls.length > 0) {
        for (const id of ids) {
          await supabase
            .from("products")
            .update({ photo_urls: imageUrls })
            .eq("id", id);
        }
        fixed += ids.length;
        if (checked % 10 === 0 || checked <= 3) {
          console.log(`  [${checked}/${seoMap.size}] ${seoId} → ${imageUrls.length} images (${ids.length} products)`);
        }
      } else {
        failed += ids.length;
      }

      await new Promise((r) => setTimeout(r, 300));
    } catch {
      failed += ids.length;
    }
  }

  console.log(`\n=== Risultato ===`);
  console.log(`Immagini corrette: ${fixed} prodotti`);
  console.log(`Non aggiornati: ${failed} prodotti`);

  // Verify a few
  console.log("\n--- Verifica URL corretti ---");
  const { data: sample } = await supabase
    .from("products")
    .select("name, photo_urls")
    .not("photo_urls", "eq", "{}")
    .limit(3);

  for (const p of sample || []) {
    const urls = p.photo_urls as string[];
    if (urls.length > 0) {
      const resp = await fetch(urls[0], { method: "HEAD" });
      const ct = resp.headers.get("content-type") || "";
      console.log(`  [${resp.status}] ${ct} → "${p.name}"`);
    }
  }
}

fixImages().catch(console.error);
