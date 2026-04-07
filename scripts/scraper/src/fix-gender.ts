import { supabase } from "./config.js";

const HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
  Accept: "application/json",
  "Accept-Language": "it-IT,it;q=0.9",
};

function extractSeoId(url: string): string | null {
  const match = url.match(/-p(\d+)\.html/);
  return match ? match[1] : null;
}

async function fetchGenderFromApi(
  seoId: string,
  keyword: string
): Promise<"uomo" | "donna" | null> {
  try {
    const url = `https://www.zara.com/it/it/${keyword}-p${seoId}.html?ajax=true`;
    const resp = await fetch(url, { headers: HEADERS });

    if (resp.status === 278) {
      const redir = await resp.json();
      if (redir.location) {
        const resp2 = await fetch(redir.location, { headers: HEADERS });
        if (!resp2.ok) return null;
        const data = await resp2.json();
        return mapSection(data.product?.sectionName);
      }
      return null;
    }

    if (!resp.ok) return null;
    const data = await resp.json();
    return mapSection(data.product?.sectionName);
  } catch {
    return null;
  }
}

function mapSection(section: string | undefined): "uomo" | "donna" | null {
  if (!section) return null;
  const s = section.toUpperCase();
  if (s === "MAN" || s === "UOMO") return "uomo";
  if (s === "WOMAN" || s === "DONNA") return "donna";
  return null;
}

async function fixGender() {
  const { data: products } = await supabase
    .from("products")
    .select("id, name, affiliate_url")
    .eq("gender", "unisex");

  if (!products?.length) {
    console.log("No unisex products to fix");
    return;
  }

  console.log(`Fixing gender for ${products.length} unisex products via Zara API...\n`);

  let uomo = 0;
  let donna = 0;
  let failed = 0;

  // Group by seoId to avoid duplicate API calls (same product, different colors)
  const seoIdMap = new Map<string, string[]>();
  for (const p of products) {
    const seoId = extractSeoId(p.affiliate_url || "");
    if (seoId) {
      if (!seoIdMap.has(seoId)) seoIdMap.set(seoId, []);
      seoIdMap.get(seoId)!.push(p.id);
    }
  }

  console.log(`Unique seoIds to check: ${seoIdMap.size}`);

  // Cache: seoId → gender
  const genderCache = new Map<string, "uomo" | "donna" | null>();

  let checked = 0;
  for (const [seoId, productIds] of seoIdMap) {
    // Extract keyword from first product's URL for API call
    const product = products.find((p) =>
      productIds.includes(p.id)
    );
    const urlMatch = product?.affiliate_url?.match(
      /\/it\/it\/(.+)-p\d+\.html/
    );
    const keyword = urlMatch?.[1] || "product";

    const gender = await fetchGenderFromApi(seoId, keyword);
    genderCache.set(seoId, gender);
    checked++;

    if (gender) {
      // Update all products with this seoId
      for (const id of productIds) {
        await supabase.from("products").update({ gender }).eq("id", id);
      }
      if (gender === "uomo") uomo += productIds.length;
      else donna += productIds.length;
      process.stdout.write(`  [${checked}/${seoIdMap.size}] ${seoId} → ${gender} (${productIds.length} products)\n`);
    } else {
      failed += productIds.length;
      process.stdout.write(`  [${checked}/${seoIdMap.size}] ${seoId} → ? (${productIds.length} products)\n`);
    }

    // Rate limit
    await new Promise((r) => setTimeout(r, 300));
  }

  console.log(`\n=== Results ===`);
  console.log(`uomo: ${uomo}`);
  console.log(`donna: ${donna}`);
  console.log(`still unisex: ${failed}`);
}

fixGender().catch(console.error);
