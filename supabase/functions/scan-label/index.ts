import "jsr:@supabase/functions-js/edge-runtime.d.ts";

// ---------- Known fibers (mirrored from src/constants/fibers.ts) ----------

const KNOWN_FIBERS: Record<string, string> = {
  // premium
  cashmere: "cashmere",
  cachemire: "cashmere",
  kashmir: "cashmere",
  seta: "silk",
  silk: "silk",
  "lana merino": "merino_wool",
  "merino wool": "merino_wool",
  merino: "merino_wool",
  "cotone supima": "supima_cotton",
  "supima cotton": "supima_cotton",
  supima: "supima_cotton",
  "cotone pima": "pima_cotton",
  "pima cotton": "pima_cotton",
  pima: "pima_cotton",
  "cotone egiziano": "egyptian_cotton",
  "egyptian cotton": "egyptian_cotton",
  // alto
  lino: "linen",
  linen: "linen",
  "cotone biologico": "organic_cotton",
  "organic cotton": "organic_cotton",
  "cotone organico": "organic_cotton",
  lyocell: "lyocell",
  tencel: "tencel",
  // medio_alto
  cotone: "cotton",
  cotton: "cotton",
  modal: "modal",
  // medio
  viscosa: "viscose",
  viscose: "viscose",
  rayon: "rayon",
  nylon: "nylon",
  poliammide: "polyamide",
  polyamide: "polyamide",
  "poliestere riciclato": "recycled_polyester",
  "recycled polyester": "recycled_polyester",
  // basso
  poliestere: "polyester",
  polyester: "polyester",
  acrilico: "acrylic",
  acrylic: "acrylic",
  // neutro
  elastan: "elastane",
  elastane: "elastane",
  spandex: "spandex",
  lycra: "elastane",
};

function normalizeFiber(raw: string): string {
  const key = raw.trim().toLowerCase();
  return KNOWN_FIBERS[key] ?? key;
}

// ---------- Types ----------

interface Composition {
  fiber: string;
  percentage: number;
}

interface ScanLabelResult {
  composition: Composition[];
  country_of_production: string | null;
  care_instructions: string | null;
}

interface RequestBody {
  image_base64: string;
  media_type?: "image/jpeg" | "image/png" | "image/webp" | "image/gif";
}

// ---------- Prompt ----------

const SYSTEM_PROMPT = `Sei un esperto di etichette tessili. Analizza l'immagine dell'etichetta di un capo di abbigliamento ed estrai le seguenti informazioni in formato JSON.

Regole:
- composition: array di oggetti {fiber, percentage}. Usa il nome della fibra esattamente come scritto sull'etichetta (es. "Cotone", "Poliestere", "Elastan"). Le percentuali devono sommare a 100.
- country_of_production: il paese di produzione se indicato (es. "Italia", "Bangladesh", "Cina"). null se non presente.
- care_instructions: le istruzioni di lavaggio/cura come testo libero (es. "Lavare a 30°C, Non candeggiare, Asciugare in piano"). null se non presenti. Se ci sono simboli di lavaggio, descrivili testualmente.

Rispondi SOLO con JSON valido, senza markdown, senza commenti. Esempio:
{"composition":[{"fiber":"Cotone","percentage":95},{"fiber":"Elastan","percentage":5}],"country_of_production":"Bangladesh","care_instructions":"Lavare a 30°C, Non candeggiare"}`;

// ---------- Handler ----------

Deno.serve(async (req: Request) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers":
          "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  if (req.method !== "POST") {
    return Response.json({ error: "Method not allowed" }, { status: 405 });
  }

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) {
    return Response.json(
      { error: "ANTHROPIC_API_KEY not configured" },
      { status: 500 },
    );
  }

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return Response.json({ error: "Invalid JSON body" }, { status: 400 });
  }

  const { image_base64, media_type = "image/jpeg" } = body;

  if (!image_base64) {
    return Response.json(
      { error: "image_base64 is required" },
      { status: 400 },
    );
  }

  // Call Claude API with vision
  const claudeResponse = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: "claude-sonnet-4-20250514",
      max_tokens: 1024,
      system: SYSTEM_PROMPT,
      messages: [
        {
          role: "user",
          content: [
            {
              type: "image",
              source: {
                type: "base64",
                media_type: media_type,
                data: image_base64,
              },
            },
            {
              type: "text",
              text: "Analizza questa etichetta ed estrai composizione, paese di produzione e istruzioni di lavaggio.",
            },
          ],
        },
      ],
    }),
  });

  if (!claudeResponse.ok) {
    const err = await claudeResponse.text();
    return Response.json(
      { error: "Claude API error", details: err },
      { status: 502 },
    );
  }

  const claudeData = await claudeResponse.json();
  const textBlock = claudeData.content?.find(
    (b: { type: string }) => b.type === "text",
  );

  if (!textBlock?.text) {
    return Response.json(
      { error: "No text response from Claude" },
      { status: 502 },
    );
  }

  // Parse the JSON from Claude's response
  let parsed: ScanLabelResult;
  try {
    parsed = JSON.parse(textBlock.text);
  } catch {
    return Response.json(
      { error: "Failed to parse Claude response as JSON", raw: textBlock.text },
      { status: 502 },
    );
  }

  // Normalize fiber names to known IDs
  const composition: Composition[] = (parsed.composition ?? []).map((c) => ({
    fiber: normalizeFiber(c.fiber),
    percentage: c.percentage,
  }));

  // Validate: sum should be ~100%
  const sum = composition.reduce((s, c) => s + c.percentage, 0);
  const sumValid = sum >= 99 && sum <= 101;

  const result = {
    composition,
    country_of_production: parsed.country_of_production ?? null,
    care_instructions: parsed.care_instructions ?? null,
    _meta: {
      composition_sum: sum,
      composition_sum_valid: sumValid,
      fibers_count: composition.length,
    },
  };

  return Response.json(result, {
    headers: {
      "Access-Control-Allow-Origin": "*",
      "Content-Type": "application/json",
    },
  });
});
