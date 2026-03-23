-- Review-Likes: "Hilfreich markieren" Feature
-- Nutzer können Reviews liken, Like-Count wird angezeigt

-- 1. review_likes Tabelle
CREATE TABLE IF NOT EXISTS public.review_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    review_id UUID NOT NULL REFERENCES public.reviews(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(review_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_review_likes_review_id ON public.review_likes(review_id);
CREATE INDEX IF NOT EXISTS idx_review_likes_user_id ON public.review_likes(user_id);

-- 2. RLS: Jeder eingeloggte User kann Likes lesen, eigene erstellen/löschen
ALTER TABLE public.review_likes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "review_likes_select_authenticated" ON public.review_likes;
CREATE POLICY "review_likes_select_authenticated"
  ON public.review_likes
  FOR SELECT
  TO authenticated
  USING (true);

DROP POLICY IF EXISTS "review_likes_insert_own" ON public.review_likes;
CREATE POLICY "review_likes_insert_own"
  ON public.review_likes
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "review_likes_delete_own" ON public.review_likes;
CREATE POLICY "review_likes_delete_own"
  ON public.review_likes
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- 3. RPC: Like toggeln — gibt neuen Status + Count zurück
CREATE OR REPLACE FUNCTION public.toggle_review_like(p_review_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_exists BOOLEAN;
  v_like_count INT;
  v_liked BOOLEAN;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT EXISTS(
    SELECT 1 FROM public.review_likes
    WHERE review_id = p_review_id AND user_id = v_user_id
  ) INTO v_exists;

  IF v_exists THEN
    DELETE FROM public.review_likes
    WHERE review_id = p_review_id AND user_id = v_user_id;
    v_liked := false;
  ELSE
    INSERT INTO public.review_likes (review_id, user_id)
    VALUES (p_review_id, v_user_id);
    v_liked := true;
  END IF;

  SELECT count(*)::INT INTO v_like_count
  FROM public.review_likes
  WHERE review_id = p_review_id;

  RETURN json_build_object('liked', v_liked, 'like_count', v_like_count);
END;
$$;

-- 4. RPC: Like-Status für mehrere Reviews (Batch) laden
CREATE OR REPLACE FUNCTION public.get_review_likes_batch(p_review_ids UUID[])
RETURNS TABLE (
  review_id UUID,
  like_count INT,
  is_liked BOOLEAN
)
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, auth
AS $$
  SELECT
    r_id AS review_id,
    (SELECT count(*)::INT FROM public.review_likes rl WHERE rl.review_id = r_id) AS like_count,
    EXISTS(
      SELECT 1 FROM public.review_likes rl
      WHERE rl.review_id = r_id AND rl.user_id = auth.uid()
    ) AS is_liked
  FROM unnest(p_review_ids) AS r_id;
$$;

-- 5. Grants
GRANT SELECT, INSERT, DELETE ON public.review_likes TO authenticated;
GRANT EXECUTE ON FUNCTION public.toggle_review_like(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_review_likes_batch(UUID[]) TO authenticated;
