import "dotenv/config";
import { createClient } from "@supabase/supabase-js";

const sb = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);
const { data, error } = await sb
  .from("brands")
  .select("id, slug, name, market_segment, origin_country")
  .eq("slug", "lacoste")
  .maybeSingle();
if (error) { console.error("Errore:", error.message); process.exit(1); }
if (!data) { console.log("Brand 'lacoste' NON trovato."); process.exit(0); }

console.log("Brand 'lacoste' trovato:");
console.log(`  id:             ${data.id}`);
console.log(`  name:           ${data.name}`);
console.log(`  market_segment: ${data.market_segment}`);
console.log(`  origin_country: ${data.origin_country}`);

const { count } = await sb
  .from("products")
  .select("*", { count: "exact", head: true })
  .eq("brand_id", data.id);
console.log(`  products:       ${count}`);
