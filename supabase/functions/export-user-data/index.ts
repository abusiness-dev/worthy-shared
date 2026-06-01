// export-user-data
// -----------------
// GDPR Art. 20 (portabilità). Esporta TUTTI i dati dell'utente CHIAMANTE in JSON.
//
// SICUREZZA / ANTI-IDOR
// ---------------------
// - JWT obbligatorio: l'utente è SEMPRE auth.getUser() (auth.uid()).
//   NON viene mai letto uno userId dal body → impossibile esportare i dati di
//   un altro utente.
// - Le query girano con service_role (bypassa RLS) MA sono SEMPRE filtrate per
//   l'id del chiamante. Nessun parametro utente finisce nelle query.
// - Throttle stretto: l'export è pesante.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const FUNCTION_NAME = "export-user-data";
const RATE_LIMIT_MAX = 2;
const RATE_LIMIT_WINDOW = "1 minute";

// Tabelle da esportare: { tabella, colonna che lega all'utente }
const EXPORT_TABLES: { table: string; column: string }[] = [
  { table: "users", column: "id" },
  { table: "scan_history", column: "user_id" },
  { table: "saved_products", column: "user_id" },
  { table: "saved_comparisons", column: "user_id" },
  { table: "product_votes", column: "user_id" },
  { table: "product_reports", column: "user_id" },
  { table: "user_consents", column: "user_id" },
  { table: "user_badges", column: "user_id" },
  { table: "user_brand_preferences", column: "user_id" },
  { table: "user_category_preferences", column: "user_id" },
  { table: "products", column: "contributed_by" }, // prodotti contribuiti
];

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceKey) {
    return jsonResponse({ error: "Server misconfigured" }, 500);
  }

  // Auth — l'unico utente esportabile è il chiamante (anti-IDOR).
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

  // Raccolta dati, sempre filtrata per l'id del chiamante.
  const data: Record<string, unknown> = {};
  for (const { table, column } of EXPORT_TABLES) {
    const { data: rows, error } = await svc.from(table).select("*").eq(column, userId);
    if (error) {
      console.error(`export ${table} error`, error);
      return jsonResponse({ error: "Export failed" }, 500);
    }
    data[table] = rows ?? [];
  }

  return jsonResponse(
    {
      export_version: 1,
      user_id: userId,
      exported_at: new Date().toISOString(),
      data,
    },
    200,
  );
});
