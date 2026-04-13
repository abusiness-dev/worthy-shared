-- ============================================================
-- AUTH PROFILE BOOTSTRAP + AVATARS STORAGE
-- 1. Trigger: crea automaticamente public.users quando nasce auth.users
-- 2. Backfill: utenti esistenti senza profilo
-- 3. Bucket storage 'avatars' + RLS policies su storage.objects
-- ============================================================

-- ------------------------------------------------------------
-- 1. Funzione handle_new_user + trigger
-- ------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  display_name_value text;
BEGIN
  -- Email mancante: niente da fare (signup non valido)
  IF NEW.email IS NULL THEN
    RETURN NEW;
  END IF;

  -- Calcola display_name con fallback intelligenti
  display_name_value := COALESCE(
    NEW.raw_user_meta_data->>'display_name',
    NEW.raw_user_meta_data->>'full_name',
    NEW.raw_user_meta_data->>'name',
    NULL
  );

  -- Apple "Hide My Email" → email finta @privaterelay.appleid.com.
  -- Evita di mostrare lo username random come display name.
  IF display_name_value IS NULL THEN
    IF NEW.email LIKE '%@privaterelay.appleid.com' THEN
      display_name_value := 'Utente Worthy';
    ELSE
      display_name_value := split_part(NEW.email, '@', 1);
    END IF;
  END IF;

  BEGIN
    INSERT INTO public.users (id, email, display_name, avatar_url)
    VALUES (
      NEW.id,
      NEW.email,
      display_name_value,
      NEW.raw_user_meta_data->>'avatar_url'
    );
  EXCEPTION
    WHEN unique_violation THEN
      -- profilo già esistente (backfill precedente o race rara): ignora
      NULL;
    WHEN OTHERS THEN
      -- Non bloccare mai l'auth: logga e continua
      RAISE WARNING 'handle_new_user failed for %: %', NEW.id, SQLERRM;
  END;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.handle_new_user IS
  'Crea automaticamente public.users quando un nuovo auth.users viene inserito. Robusto a race condition e fallimenti, non blocca mai l''auth.';

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- ------------------------------------------------------------
-- 2. Backfill utenti esistenti
-- ------------------------------------------------------------

INSERT INTO public.users (id, email, display_name, avatar_url)
SELECT
  au.id,
  au.email,
  COALESCE(
    au.raw_user_meta_data->>'display_name',
    au.raw_user_meta_data->>'full_name',
    au.raw_user_meta_data->>'name',
    CASE
      WHEN au.email LIKE '%@privaterelay.appleid.com' THEN 'Utente Worthy'
      ELSE split_part(au.email, '@', 1)
    END
  ),
  au.raw_user_meta_data->>'avatar_url'
FROM auth.users au
LEFT JOIN public.users pu ON pu.id = au.id
WHERE pu.id IS NULL
  AND au.email IS NOT NULL
ON CONFLICT (id) DO NOTHING;

-- ------------------------------------------------------------
-- 3. Storage bucket 'avatars'
-- ------------------------------------------------------------

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars',
  'avatars',
  true,                      -- public read
  2 * 1024 * 1024,           -- 2 MB cap
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE
SET public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- ------------------------------------------------------------
-- 4. RLS policies su storage.objects per bucket 'avatars'
--    Path obbligatorio: {user_id}/...
-- ------------------------------------------------------------

-- SELECT pubblico
DROP POLICY IF EXISTS "avatars_public_read" ON storage.objects;
CREATE POLICY "avatars_public_read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'avatars');

-- INSERT: solo authenticated, path deve iniziare con {auth.uid()}/
DROP POLICY IF EXISTS "avatars_insert_own" ON storage.objects;
CREATE POLICY "avatars_insert_own"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- UPDATE: stesso owner (per upsert)
DROP POLICY IF EXISTS "avatars_update_own" ON storage.objects;
CREATE POLICY "avatars_update_own"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- DELETE: stesso owner
DROP POLICY IF EXISTS "avatars_delete_own" ON storage.objects;
CREATE POLICY "avatars_delete_own"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
