// match-product-by-tag
// ---------------------
// Fallback OCR + fuzzy-search quando lo scanner barcode di worthy-app non trova
// il prodotto. Il client invia base64 di una foto al cartellino-prezzo; questa
// function estrae brand + nome con Claude Haiku, poi chiama search_products_fuzzy
// per ottenere top-5 candidati.
//
// PRIVACY
// -------
// Le immagini non vengono mai salvate. In `label_ocr_cache` persistiamo solo:
//   - SHA-256 hex dell'immagine (chiave di cache)
//   - testo estratto dall'OCR (brand + nome prodotto)
//   - confidence + nome modello
// La cache scade dopo 24h (cron pulizia ogni 6h).
//
// SICUREZZA
// ---------
// - JWT richiesto: getUser() rifiuta richieste anon.
// - Rate limit 5/min/utente (RPC atomica check_and_record_throttle).
// - Size limit 8MB sul base64 (~6MB binari) per evitare DoS economico verso Claude.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// ---------- Constants ----------

const FUNCTION_NAME = "match-product-by-tag";
const MODEL = "claude-haiku-4-5";
const MAX_BASE64_BYTES = 8 * 1024 * 1024; // 8 MB
const RATE_LIMIT_MAX = 5;
const RATE_LIMIT_WINDOW = "1 minute";
const CANDIDATES_MAX = 5;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SYSTEM_PROMPT = `Analizza questa foto di un cartellino di un prodotto di moda/abbigliamento.
Estrai SOLO:
- "detected_brand": il nome del brand (marchio), o "" se non leggibile
- "detected_product_name": il nome/modello del prodotto, o "" se non leggibile
- "ocr_confidence": 0..1, quanto sei sicuro della lettura

Rispondi SOLO JSON valido, senza markdown, senza commenti. Esempio:
{"detected_brand":"Nike","detected_product_name":"Air Max 90","ocr_confidence":0.9}`;

// ---------- Types ----------

interface RequestBody {
  image_base64: string;
  media_type?: "image/jpeg" | "image/png" | "image/webp" | "image/gif";
}

interface OcrResult {
  detected_brand: string;
  detected_product_name: string;
  ocr_confidence: number;
}

interface Detected {
  brand: string;
  name: string;
  confidence: number;
}

interface Candidate {
  product_id: string;
  slug: string;
  name: string;
  brand_name: string;
  photo_url: string | null;
  sim: number;
}

interface ResponseBody {
  detected: Detected;
  candidates: Candidate[];
  _meta: { cached: boolean; model: string };
}

// ---------- Helpers ----------

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

async function sha256Hex(base64: string): Promise<string> {
  const bin = atob(base64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  const buf = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(buf))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

async function callClaudeOcr(
  apiKey: string,
  imageBase64: string,
  mediaType: string,
): Promise<OcrResult | null> {
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: MODEL,
      max_tokens: 200,
      system: SYSTEM_PROMPT,
      messages: [
        {
          role: "user",
          content: [
            {
              type: "image",
              source: { type: "base64", media_type: mediaType, data: imageBase64 },
            },
            {
              type: "text",
              text: "Estrai brand e nome prodotto dal cartellino.",
            },
          ],
        },
      ],
    }),
  });

  if (!res.ok) {
    console.error("Claude API error", res.status, await res.text());
    return null;
  }

  const data = await res.json();
  const textBlock = data.content?.find(
    (b: { type: string }) => b.type === "text",
  );
  if (!textBlock?.text) return null;

  try {
    const parsed = JSON.parse(textBlock.text);
    return {
      detected_brand: String(parsed.detected_brand ?? "").trim(),
      detected_product_name: String(parsed.detected_product_name ?? "").trim(),
      ocr_confidence: Math.max(0, Math.min(1, Number(parsed.ocr_confidence) || 0)),
    };
  } catch {
    return null;
  }
}

// ---------- Handler ----------

Deno.serve(async (req: Request) => {
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
  const { image_base64, media_type = "image/jpeg" } = body;
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

  // Service-role client per cache + RPC
  const svc = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Throttle
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

  // Hash + cache lookup
  const hash = await sha256Hex(image_base64);
  let detected: Detected = { brand: "", name: "", confidence: 0 };
  let cached = false;

  const { data: cacheRow } = await svc
    .from("label_ocr_cache")
    .select("detected_brand, detected_name, confidence")
    .eq("image_sha256", hash)
    .gt("expires_at", new Date().toISOString())
    .maybeSingle();

  if (cacheRow) {
    detected = {
      brand: cacheRow.detected_brand ?? "",
      name: cacheRow.detected_name ?? "",
      confidence: Number(cacheRow.confidence ?? 0),
    };
    cached = true;
  } else {
    // OCR Claude
    const ocr = await callClaudeOcr(anthropicKey, image_base64, media_type);
    if (ocr) {
      detected = {
        brand: ocr.detected_brand,
        name: ocr.detected_product_name,
        confidence: ocr.ocr_confidence,
      };
      // Upsert cache: ON CONFLICT (image_sha256) DO NOTHING — race-safe.
      await svc.from("label_ocr_cache").upsert(
        {
          image_sha256: hash,
          detected_brand: detected.brand,
          detected_name: detected.name,
          confidence: detected.confidence,
          model: MODEL,
        },
        { onConflict: "image_sha256", ignoreDuplicates: true },
      );
    }
    // Se ocr === null (Claude error o parse fail): detected resta vuoto, candidates = []
  }

  // Fuzzy search (skip se nulla da cercare)
  let candidates: Candidate[] = [];
  if (detected.brand || detected.name) {
    const { data: rows, error: rpcErr } = await svc.rpc("search_products_fuzzy", {
      p_brand: detected.brand,
      p_product: detected.name,
      p_max: CANDIDATES_MAX,
    });
    if (rpcErr) {
      console.error("search_products_fuzzy error", rpcErr);
      return jsonResponse({ error: "Search failed" }, 500);
    }
    candidates = (rows ?? []).map((r: Candidate) => ({
      product_id: r.product_id,
      slug: r.slug,
      name: r.name,
      brand_name: r.brand_name,
      photo_url: r.photo_url ?? null,
      sim: Number(r.sim),
    }));
  }

  const response: ResponseBody = {
    detected,
    candidates,
    _meta: { cached, model: MODEL },
  };
  return jsonResponse(response, 200);
});
