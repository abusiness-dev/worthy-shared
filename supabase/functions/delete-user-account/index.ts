// delete-user-account
// --------------------
// GDPR Art. 17 (diritto all'oblio). Cancella l'account dell'utente CHIAMANTE.
//
// SICUREZZA / ANTI-IDOR
// ---------------------
// - JWT obbligatorio: l'utente target è SEMPRE auth.getUser() (auth.uid()).
//   NON viene mai letto uno userId dal body → impossibile cancellare un altro
//   utente passando un id arbitrario.
// - La cancellazione usa auth.admin.deleteUser(uid): elimina la riga in
//   auth.users, che per FK ON DELETE CASCADE elimina public.users e a cascata
//   tutte le tabelle figlie (scan_history, saved_*, product_votes,
//   product_reports, user_consents, user_badges, user_*_preferences,
//   function_calls_throttle). products.contributed_by → SET NULL (il catalogo
//   resta, ma anonimizzato).
// - Throttle per evitare abusi accidentali/automatizzati.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const FUNCTION_NAME = "delete-user-account";
const RATE_LIMIT_MAX = 3;
const RATE_LIMIT_WINDOW = "1 minute";

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

  // Auth — l'unico utente cancellabile è il chiamante (anti-IDOR).
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

  // Cancellazione: auth.users → CASCADE su tutto il resto.
  const { error: deleteErr } = await svc.auth.admin.deleteUser(userId);
  if (deleteErr) {
    console.error("deleteUser error", deleteErr);
    return jsonResponse({ error: "Account deletion failed" }, 500);
  }

  return jsonResponse({ success: true, deleted_user_id: userId }, 200);
});
