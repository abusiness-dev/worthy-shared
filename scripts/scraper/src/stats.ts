import { supabase } from "./config.js";

async function stats() {
  const { count: total } = await supabase
    .from("products")
    .select("*", { count: "exact", head: true });

  const { count: uomo } = await supabase
    .from("products")
    .select("*", { count: "exact", head: true })
    .eq("gender", "uomo");

  const { count: donna } = await supabase
    .from("products")
    .select("*", { count: "exact", head: true })
    .eq("gender", "donna");

  const { count: unisex } = await supabase
    .from("products")
    .select("*", { count: "exact", head: true })
    .eq("gender", "unisex");

  const { count: steal } = await supabase
    .from("products")
    .select("*", { count: "exact", head: true })
    .eq("verdict", "steal");

  const { count: worthy } = await supabase
    .from("products")
    .select("*", { count: "exact", head: true })
    .eq("verdict", "worthy");

  const { count: fair } = await supabase
    .from("products")
    .select("*", { count: "exact", head: true })
    .eq("verdict", "fair");

  const { count: meh } = await supabase
    .from("products")
    .select("*", { count: "exact", head: true })
    .eq("verdict", "meh");

  const { count: not_worthy } = await supabase
    .from("products")
    .select("*", { count: "exact", head: true })
    .eq("verdict", "not_worthy");

  // Price range
  const { data: priceData } = await supabase
    .from("products")
    .select("price")
    .order("price", { ascending: true })
    .limit(1);

  const { data: priceDataMax } = await supabase
    .from("products")
    .select("price")
    .order("price", { ascending: false })
    .limit(1);

  console.log("=== DATABASE STATS ===");
  console.log(`Total products: ${total}`);
  console.log(`By gender: uomo=${uomo}, donna=${donna}, unisex=${unisex}`);
  console.log(
    `By verdict: steal=${steal} | worthy=${worthy} | fair=${fair} | meh=${meh} | not_worthy=${not_worthy}`
  );
  console.log(
    `Price range: ${priceData?.[0]?.price}€ - ${priceDataMax?.[0]?.price}€`
  );
}

stats().catch(console.error);
