-- Review-Validierung: Constraints + RLS
-- Schützt vor ungültigen Daten selbst wenn der Client umgangen wird.

-- 1. CHECK-Constraints auf der reviews-Tabelle
ALTER TABLE reviews
  ADD CONSTRAINT reviews_rating_range
    CHECK (rating >= 1 AND rating <= 5),
  ADD CONSTRAINT reviews_text_length
    CHECK (char_length(trim(text)) >= 10 AND char_length(text) <= 500),
  ADD CONSTRAINT reviews_title_length
    CHECK (char_length(title) <= 100),
  ADD CONSTRAINT reviews_longevity_range
    CHECK (longevity IS NULL OR (longevity >= 0 AND longevity <= 100)),
  ADD CONSTRAINT reviews_sillage_range
    CHECK (sillage IS NULL OR (sillage >= 0 AND sillage <= 100));

-- 2. author_name-Format: Nur Buchstaben, Zahlen, Leerzeichen, Bindestriche, Punkte, Unterstriche (1-50 Zeichen)
ALTER TABLE reviews
  ADD CONSTRAINT reviews_author_name_format
    CHECK (
      author_name IS NULL
      OR (
        char_length(trim(author_name)) >= 1
        AND char_length(author_name) <= 50
        AND author_name ~ '^[\w\s.\-äöüÄÖÜß]+$'
      )
    );

-- 3. RLS: User darf nur eigene Reviews erstellen/ändern/löschen
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY IF NOT EXISTS "reviews_select_all"
  ON reviews FOR SELECT
  USING (true);

CREATE POLICY IF NOT EXISTS "reviews_insert_own"
  ON reviews FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY IF NOT EXISTS "reviews_update_own"
  ON reviews FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY IF NOT EXISTS "reviews_delete_own"
  ON reviews FOR DELETE
  USING (auth.uid() = user_id);
