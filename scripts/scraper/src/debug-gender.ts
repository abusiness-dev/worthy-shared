import { supabase } from "./config.js";

async function debug() {
  const { data: products } = await supabase
    .from("products")
    .select("id, name, affiliate_url, gender")
    .eq("gender", "unisex")
    .limit(30);

  if (!products?.length) {
    console.log("No unisex products");
    return;
  }

  console.log(`Unisex products sample (${products.length}):\n`);
  for (const p of products) {
    console.log(`  "${p.name}"`);
    console.log(`  URL: ${p.affiliate_url || "(none)"}\n`);
  }
}

debug().catch(console.error);
