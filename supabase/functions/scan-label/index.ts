// scan-label
// ----------
// OCR di etichette tessili (composizione, paese, istruzioni lavaggio) via Claude
// Sonnet 4 (vision). Il client invia il base64 di una foto dell'etichetta.
//
// SICUREZZA (allineata a match-product-by-tag)
// --------------------------------------------
// - JWT richiesto: auth.getUser() rifiuta richieste anon (la Claude API key è a
//   nostro carico → senza auth chiunque con la anon key pubblica può bruciarla).
// - Rate limit per-utente via RPC atomica check_and_record_throttle.
// - Size limit 8MB sul base64 (~6MB binari) per evitare DoS economico/memoria.
// - Validazione media_type (allowlist).
// - Errori generici al client: dettagli upstream solo nei log server-side.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// ---------- Constants ----------

const FUNCTION_NAME = "scan-label";
const MODEL = "claude-sonnet-4-20250514";
const MAX_BASE64_BYTES = 8 * 1024 * 1024; // 8 MB
const RATE_LIMIT_MAX = 10;
const RATE_LIMIT_WINDOW = "1 minute";
const CLAUDE_TIMEOUT_MS = 20_000; // hard timeout sulla fetch a Claude

// Client service-role riusato tra invocazioni nello stesso isolate (privo di stato
// per-request; l'authClient resta invece per-richiesta perché porta il JWT utente).
let _svc: ReturnType<typeof createClient> | null = null;
function getServiceClient(url: string, key: string) {
  if (!_svc) {
    _svc = createClient(url, key, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
  }
  return _svc;
}

const ALLOWED_MEDIA_TYPES = [
  "image/jpeg",
  "image/png",
  "image/webp",
  "image/gif",
] as const;
type MediaType = (typeof ALLOWED_MEDIA_TYPES)[number];

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

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
  media_type?: MediaType;
}

// ---------- Prompt ----------

const SYSTEM_PROMPT = `Sei un esperto di etichette tessili. Analizza l'immagine dell'etichetta di un capo di abbigliamento ed estrai le seguenti informazioni in formato JSON.

Regole:
- composition: array di oggetti {fiber, percentage}. Usa il nome della fibra esattamente come scritto sull'etichetta (es. "Cotone", "Poliestere", "Elastan"). Le percentuali devono sommare a 100.
- country_of_production: il paese di produzione se indicato (es. "Italia", "Bangladesh", "Cina"). null se non presente.
- care_instructions: le istruzioni di lavaggio/cura come testo libero (es. "Lavare a 30°C, Non candeggiare, Asciugare in piano"). null se non presenti. Se ci sono simboli di lavaggio, descrivili testualmente.

Rispondi SOLO con JSON valido, senza markdown, senza commenti. Esempio:
{"composition":[{"fiber":"Cotone","percentage":95},{"fiber":"Elastan","percentage":5}],"country_of_production":"Bangladesh","care_instructions":"Lavare a 30°C, Non candeggiare"}`;

// ---------- Helpers ----------

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

// ---------- Handler ----------

Deno.serve(async (req: Request) => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  // Env
  const anthropicKey = Deno.env.get("ANTHROPIC_API_KEY");
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!anthropicKey || !supabaseUrl || !anonKey || !serviceKey) {
    return jsonResponse({ error: "Server misconfigured" }, 500);
  }

  // Body
  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }

  const { image_base64 } = body;
  const media_type: MediaType = ALLOWED_MEDIA_TYPES.includes(
    body.media_type as MediaType,
  )
    ? (body.media_type as MediaType)
    : "image/jpeg";

  if (!image_base64 || typeof image_base64 !== "string") {
    return jsonResponse({ error: "image_base64 is required" }, 400);
  }
  if (image_base64.length > MAX_BASE64_BYTES) {
    return jsonResponse({ error: "Image too large (max 8MB base64)" }, 413);
  }

  // Auth (verifica firma JWT lato Supabase Auth)
  const authHeader = req.headers.get("Authorization") ?? "";
  const authClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userErr } = await authClient.auth.getUser();
  if (userErr || !userData?.user) {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }
  const userId = userData.user.id;

  // Service-role client per throttle/budget (RPC REVOKEd da anon/authenticated:
  // solo service_role può chiamarle). Riusato tra invocazioni.
  const svc = getServiceClient(supabaseUrl, serviceKey);

  // Throttle — PRIMA della chiamata costosa a Claude.
  const { data: allowed, error: throttleErr } = await svc.rpc(
    "check_and_record_throttle",
    {
      p_user_id: userId,
      p_function: FUNCTION_NAME,
      p_max: RATE_LIMIT_MAX,
      p_window: RATE_LIMIT_WINDOW,
    },
  );
  if (throttleErr) {
    console.error("Throttle RPC error", throttleErr);
    return jsonResponse({ error: "Throttle check failed" }, 500);
  }
  if (allowed === false) {
    return jsonResponse({ error: "Rate limit exceeded" }, 429);
  }

  // Cap di spesa GLOBALE + kill-switch (PRIMA del fetch a Claude). Protegge dalla
  // spesa Anthropic in caso di spike/abuso multi-account (il throttle per-utente
  // non si aggrega). false ⇒ OCR spento o oltre soglia oraria → 503 temporaneo.
  const { data: budgetOk, error: budgetErr } = await svc.rpc(
    "check_and_record_global_budget",
    { p_function: FUNCTION_NAME, p_window_minutes: 60 },
  );
  if (budgetErr) {
    console.error("Global budget RPC error", budgetErr);
    return jsonResponse({ error: "OCR temporarily unavailable" }, 503);
  }
  if (budgetOk === false) {
    return jsonResponse({ error: "OCR temporarily unavailable" }, 503);
  }

  // Call Claude API with vision (hard timeout via AbortController).
  const ctrl = new AbortController();
  const timeout = setTimeout(() => ctrl.abort(), CLAUDE_TIMEOUT_MS);
  let claudeResponse: Response;
  try {
    claudeResponse = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": anthropicKey,
        "anthropic-version": "2023-06-01",
      },
      signal: ctrl.signal,
      body: JSON.stringify({
        model: MODEL,
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
  } catch (e) {
    console.error("Claude fetch failed/timeout", e);
    return jsonResponse({ error: "OCR service error" }, 502);
  } finally {
    clearTimeout(timeout);
  }

  if (!claudeResponse.ok) {
    // Dettaglio upstream solo nei log server-side, mai al client.
    console.error("Claude API error", claudeResponse.status, await claudeResponse.text());
    return jsonResponse({ error: "OCR service error" }, 502);
  }

  const claudeData = await claudeResponse.json();
  const textBlock = claudeData.content?.find(
    (b: { type: string }) => b.type === "text",
  );

  if (!textBlock?.text) {
    return jsonResponse({ error: "OCR service error" }, 502);
  }

  // Parse the JSON from Claude's response
  let parsed: ScanLabelResult;
  try {
    parsed = JSON.parse(textBlock.text);
  } catch {
    // Non rimandare il testo grezzo del modello al client.
    console.error("Failed to parse Claude response as JSON");
    return jsonResponse({ error: "OCR parse error" }, 502);
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

  return jsonResponse(result, 200);
});
