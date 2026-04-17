# Security Log Alternatives — Piano B per audit_log

**Stato attuale**: `log_security_event()` usa `dblink` per autonomous transaction.
**Problema potenziale**: dblink loopback non testato su Supabase Cloud.
**Questo documento**: descrive come migrare a `pg_net` + Edge Function se dblink non funziona.

---

## Quando migrare

Migrare da dblink a pg_net se:
1. Dopo `supabase db push`, test di attacco (es. `UPDATE users SET role='admin'`) non produce righe in `audit_log` con `action='blocked'`
2. I log PostgreSQL (dashboard Supabase → Logs → Postgres) mostrano errori `log_security_event: dblink failed`
3. L'errore e persistente (non un problema transitorio di connessione)

---

## Architettura pg_net

```
[Trigger BEFORE UPDATE]
  → log_security_event()
    → net.http_post() verso Edge Function  ← pg_net (asincrono, non rollbackabile)
  → RAISE EXCEPTION
    → transazione rollbackata
    → ma la HTTP request e gia partita (fire-and-forget)

[Edge Function: audit-log-writer]
  → riceve POST con payload
  → verifica X-Audit-Secret header
  → INSERT INTO audit_log via service_role
```

`pg_net` e una extension Supabase che esegue HTTP requests in modo asincrono. A differenza di `dblink` e `pg_notify`, le request HTTP inviate da `pg_net` **non vengono rollbackate** perche sono fire-and-forget: la request parte immediatamente e il risultato viene raccolto in background.

---

## Step 1: Creare la Edge Function

File: `supabase/functions/audit-log-writer/index.ts`

```typescript
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const AUDIT_SECRET = Deno.env.get("AUDIT_SECRET");

Deno.serve(async (req) => {
  // Solo POST
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  // Verifica secret
  const secret = req.headers.get("X-Audit-Secret");
  if (!secret || secret !== AUDIT_SECRET) {
    return new Response("Unauthorized", { status: 401 });
  }

  // Parse payload
  let payload;
  try {
    payload = await req.json();
  } catch {
    return new Response("Invalid JSON", { status: 400 });
  }

  const { table, record_id, user_id, blocked_fields } = payload;

  // Validazione
  if (!table || !record_id || !blocked_fields || !Array.isArray(blocked_fields)) {
    return new Response("Missing required fields", { status: 400 });
  }

  // INSERT in audit_log via service_role
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  const { error } = await supabase.from("audit_log").insert({
    table_name: table,
    record_id,
    action: "blocked",
    user_id: user_id || null,
    new_data: {
      blocked_fields,
      blocked_at: new Date().toISOString(),
      reason: "Attempted modification of protected fields",
    },
  });

  if (error) {
    console.error("audit-log-writer error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
    });
  }

  return new Response(JSON.stringify({ ok: true }), { status: 200 });
});
```

Deploy:
```bash
supabase functions deploy audit-log-writer --no-verify-jwt
```

---

## Step 2: Configurare il secret

```sql
-- In una migration o via dashboard SQL Editor:
ALTER DATABASE postgres SET app.audit_secret = '<genera-un-uuid-v4-lungo>';
```

E nella Edge Function environment (dashboard → Edge Functions → audit-log-writer → Settings):
```
AUDIT_SECRET=<stesso-valore-di-sopra>
```

---

## Step 3: Abilitare pg_net

```sql
CREATE EXTENSION IF NOT EXISTS pg_net;
```

---

## Step 4: Modificare log_security_event

Sostituire il blocco dblink con pg_net:

```sql
CREATE OR REPLACE FUNCTION log_security_event(
  p_table text,
  p_record_id uuid,
  p_user_id uuid,
  p_blocked_fields text[]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  payload jsonb;
  project_url text;
  audit_secret text;
BEGIN
  -- Validazione input
  IF p_table IS NULL OR p_table = '' THEN
    RAISE EXCEPTION 'log_security_event: p_table cannot be null or empty';
  END IF;

  IF p_blocked_fields IS NULL OR array_length(p_blocked_fields, 1) IS NULL
     OR array_length(p_blocked_fields, 1) = 0 THEN
    RAISE EXCEPTION 'log_security_event: p_blocked_fields cannot be null or empty';
  END IF;

  payload := jsonb_build_object(
    'table', p_table,
    'record_id', p_record_id,
    'user_id', p_user_id,
    'blocked_fields', to_jsonb(p_blocked_fields)
  );

  -- Leggi la URL del progetto e il secret dai database settings
  -- Impostati con: ALTER DATABASE postgres SET app.supabase_url = '...';
  --                ALTER DATABASE postgres SET app.audit_secret = '...';
  project_url := current_setting('app.supabase_url', true);
  audit_secret := current_setting('app.audit_secret', true);

  IF project_url IS NULL OR audit_secret IS NULL THEN
    RAISE WARNING 'log_security_event: app.supabase_url or app.audit_secret not configured';
    RETURN;
  END IF;

  -- pg_net HTTP POST: fire-and-forget, NON rollbackata da RAISE EXCEPTION
  PERFORM net.http_post(
    url := project_url || '/functions/v1/audit-log-writer',
    body := payload,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'X-Audit-Secret', audit_secret
    )
  );
END;
$$;
```

---

## Step 5: Testare

1. Applicare la migration con la nuova `log_security_event`
2. Come utente autenticato, tentare:
   ```sql
   UPDATE users SET role = 'admin' WHERE id = auth.uid();
   ```
3. Verificare che l'errore viene restituito al client (RAISE EXCEPTION funziona)
4. Verificare che `audit_log` contiene una riga con `action = 'blocked'`:
   ```sql
   SELECT * FROM audit_log WHERE action = 'blocked' ORDER BY created_at DESC LIMIT 5;
   ```
5. Se la riga e presente, pg_net funziona. Se no, verificare:
   - Edge Function logs (dashboard → Edge Functions → audit-log-writer → Logs)
   - Che AUDIT_SECRET corrisponde tra DB setting e Edge Function env
   - Che pg_net extension e abilitata

---

## Step 6: Cleanup

Dopo la migrazione a pg_net, rimuovere:
```sql
DROP EXTENSION IF EXISTS dblink;
```

E aggiornare il commento di `log_security_event` per riflettere il nuovo meccanismo.

---

## Confronto finale

| Aspetto | dblink (attuale) | pg_net (alternativa) |
|---------|-----------------|---------------------|
| Persistenza log | Immediata (autonomous TX) | Asincrona (~100ms) |
| Sopravvive a RAISE EXCEPTION | SI | SI |
| Testato su Supabase Cloud | NO | SI (pg_net e nativo) |
| Dipendenze | Extension dblink | Extension pg_net + Edge Function |
| Latenza trigger | ~5-10ms (connessione locale) | ~1ms (fire-and-forget) |
| Complessita setup | Bassa (solo SQL) | Media (SQL + Edge Function + secret) |
| Costo | Zero | Edge Function invocations (incluse nel piano free fino a 500k/mese) |
