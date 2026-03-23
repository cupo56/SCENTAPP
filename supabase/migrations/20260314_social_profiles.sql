-- Social Features: Erweiterte Profile und öffentliche Sammlungen
-- Angepasst auf das aktuelle Schema

-- 1. Neue Spalten zur profiles-Tabelle hinzufügen
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS is_public BOOLEAN NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS bio TEXT,
  ADD COLUMN IF NOT EXISTS avatar_url TEXT;

-- Bio-Länge begrenzen
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'profiles_bio_length'
      AND conrelid = 'public.profiles'::regclass
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_bio_length
      CHECK (bio IS NULL OR char_length(bio) <= 200);
  END IF;
END $$;

-- Avatar-URL auf https begrenzen
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'profiles_avatar_url_https'
      AND conrelid = 'public.profiles'::regclass
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_avatar_url_https
      CHECK (avatar_url IS NULL OR avatar_url LIKE 'https://%');
  END IF;
END $$;

-- 2. RLS für öffentliche/private Profile
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles_select_all" ON public.profiles;
DROP POLICY IF EXISTS "profiles_select_public_or_own" ON public.profiles;

CREATE POLICY "profiles_select_public_or_own"
  ON public.profiles
  FOR SELECT
  USING (
    is_public = true
    OR auth.uid() = id
  );

-- 3. RPC: Öffentliches Profil mit Stats laden
CREATE OR REPLACE FUNCTION public.get_public_user_profile(target_user_id UUID)
RETURNS TABLE (
  id UUID,
  username TEXT,
  bio TEXT,
  avatar_url TEXT,
  is_public BOOLEAN,
  owned_count BIGINT,
  review_count BIGINT,
  favorite_count BIGINT,
  member_since TIMESTAMPTZ
)
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, auth
AS $$
  SELECT
    p.id,
    p.username,
    p.bio,
    p.avatar_url,
    p.is_public,
    (
      SELECT count(*)
      FROM public.user_perfumes up
      WHERE up.user_id = target_user_id
        AND up.is_owned = true
    ) AS owned_count,
    (
      SELECT count(*)
      FROM public.reviews r
      WHERE r.user_id = target_user_id
    ) AS review_count,
    (
      SELECT count(*)
      FROM public.user_perfumes up
      WHERE up.user_id = target_user_id
        AND up.is_favorite = true
    ) AS favorite_count,
    u.created_at AS member_since
  FROM public.profiles p
  LEFT JOIN auth.users u ON u.id = p.id
  WHERE p.id = target_user_id
    AND (p.is_public = true OR p.id = auth.uid());
$$;

-- 4. RPC: Öffentliche Sammlung laden (paginiert)
CREATE OR REPLACE FUNCTION public.get_public_user_collection(
  target_user_id UUID,
  p_page INT DEFAULT 0,
  p_page_size INT DEFAULT 20
)
RETURNS TABLE (
  id UUID,
  name TEXT,
  "desc" TEXT,
  image_url TEXT,
  concentration TEXT,
  longevity TEXT,
  sillage TEXT,
  performance DOUBLE PRECISION
)
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, auth
AS $$
  SELECT
    pf.id,
    pf.name,
    pf."desc",
    pf.image_url,
    pf.concentration,
    pf.longevity,
    pf.sillage,
    pf.performance
  FROM public.perfumes pf
  INNER JOIN public.user_perfumes up
    ON up.perfume_id = pf.id
  WHERE up.user_id = target_user_id
    AND up.is_owned = true
    AND EXISTS (
      SELECT 1
      FROM public.profiles pr
      WHERE pr.id = target_user_id
        AND (pr.is_public = true OR pr.id = auth.uid())
    )
  ORDER BY pf.name ASC
  OFFSET p_page * p_page_size
  LIMIT p_page_size;
$$;

-- 5. Grants
GRANT EXECUTE ON FUNCTION public.get_public_user_profile(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_public_user_collection(UUID, INT, INT) TO authenticated;
