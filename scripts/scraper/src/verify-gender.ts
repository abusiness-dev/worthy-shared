import { supabase } from "./config.js";

const HEADERS = {
  "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
  Accept: "application/json",
  "Accept-Language": "it-IT,it;q=0.9",
};

async function verify() {
  // 1. Get all products grouped by gender
  const { data: uomoProducts } = await supabase
    .from("products")
    .select("id, name, affiliate_url, price, gender")
    .eq("gender", "uomo")
    .order("name");

  const { data: donnaProducts } = await supabase
    .from("products")
    .select("id, name, affiliate_url, price, gender")
    .eq("gender", "donna")
    .order("name");

  console.log("=== VERIFICA GENERE PRODOTTI ===\n");

  // 2. Check uomo products for suspicious names (typically donna)
  const donnaKeywords = [
    "GONNA", "VESTITO", "ABITO DONNA", "REGGISENO", "BIKINI",
    "MINIGONNA", "BODY", "CROP TOP", "CORSETTO",
  ];
  const uomoKeywords = [
    "BERMUDA", "BOXER", "CRAVATTA",
  ];

  console.log("--- UOMO: controllo nomi sospetti ---");
  let uomoIssues = 0;
  for (const p of uomoProducts || []) {
    const name = p.name.toUpperCase();
    // Check if name contains donna-only patterns
    const suspicious = donnaKeywords.some((k) => name.includes(k));
    // Also flag TRF, ZW COLLECTION (Zara donna lines)
    const isDonnaLine = name.includes("TRF ") || name.includes("ZW COLLECTION");
    if (suspicious || isDonnaLine) {
      console.log(`  ⚠ "${p.name}" → segnato uomo, ma sembra donna`);
      uomoIssues++;
    }
  }
  if (uomoIssues === 0) console.log("  Nessun problema trovato.");

  console.log(`\n--- DONNA: controllo nomi sospetti ---`);
  let donnaIssues = 0;
  for (const p of donnaProducts || []) {
    const name = p.name.toUpperCase();
    // Check if name contains uomo-only patterns
    const suspicious = uomoKeywords.some((k) => name.includes(k));
    // Willy Chavarria is Zara's uomo collab
    const isUomoLine = name.includes("WILLY CHAVARRIA");
    if (suspicious || isUomoLine) {
      console.log(`  ⚠ "${p.name}" → segnata donna, ma sembra uomo`);
      donnaIssues++;
    }
  }
  if (donnaIssues === 0) console.log("  Nessun problema trovato.");

  // 3. Spot-check: verify 10 random products against Zara API
  console.log("\n--- SPOT CHECK: verifica API per 15 prodotti random ---");
  const allProducts = [...(uomoProducts || []), ...(donnaProducts || [])];
  const shuffled = allProducts.sort(() => Math.random() - 0.5).slice(0, 15);

  let correct = 0;
  let wrong = 0;
  let apiError = 0;

  for (const p of shuffled) {
    const urlMatch = p.affiliate_url?.match(/\/it\/it\/(.+)-p(\d+)\.html/);
    if (!urlMatch) {
      apiError++;
      continue;
    }

    const [, keyword, seoId] = urlMatch;
    try {
      const resp = await fetch(
        `https://www.zara.com/it/it/${keyword}-p${seoId}.html?ajax=true`,
        { headers: HEADERS }
      );

      let data: any;
      if (resp.status === 278) {
        const redir = await resp.json();
        if (redir.location) {
          const r2 = await fetch(redir.location, { headers: HEADERS });
          data = r2.ok ? await r2.json() : null;
        }
      } else if (resp.ok) {
        data = await resp.json();
      }

      if (data?.product?.sectionName) {
        const apiSection = data.product.sectionName.toUpperCase();
        const apiGender = apiSection === "MAN" ? "uomo" : apiSection === "WOMAN" ? "donna" : "?";
        const match = apiGender === p.gender;

        if (match) {
          correct++;
          console.log(`  ✓ "${p.name.substring(0, 50)}" → DB: ${p.gender}, API: ${apiGender}`);
        } else {
          wrong++;
          console.log(`  ✗ "${p.name.substring(0, 50)}" → DB: ${p.gender}, API: ${apiGender} ← ERRORE!`);
        }
      } else {
        apiError++;
        console.log(`  ? "${p.name.substring(0, 50)}" → API non disponibile`);
      }

      await new Promise((r) => setTimeout(r, 400));
    } catch {
      apiError++;
    }
  }

  console.log(`\n=== RISULTATI VERIFICA ===`);
  console.log(`Prodotti uomo: ${uomoProducts?.length}`);
  console.log(`Prodotti donna: ${donnaProducts?.length}`);
  console.log(`Nomi sospetti uomo: ${uomoIssues}`);
  console.log(`Nomi sospetti donna: ${donnaIssues}`);
  console.log(`Spot check: ${correct} corretti, ${wrong} errati, ${apiError} non verificabili`);

  // 4. If there are wrong ones, list product IDs to fix
  if (wrong > 0) {
    console.log("\n⚠ Ci sono errori da correggere!");
  } else if (correct > 0) {
    console.log("\n✓ Tutti i generi verificati sono corretti.");
  }
}

verify().catch(console.error);
