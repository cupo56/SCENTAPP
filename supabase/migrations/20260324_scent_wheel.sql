-- Scent Wheel: Duftfamilien-Kategorisierung und User-Auswertung
-- Ermöglicht die Visualisierung der Duftfamilien-Verteilung im User-Profil

-- 1. family-Spalte zur notes-Tabelle hinzufügen
ALTER TABLE public.notes
    ADD COLUMN IF NOT EXISTS family TEXT;

-- Index für schnelle Familie-Abfragen
CREATE INDEX IF NOT EXISTS idx_notes_family ON public.notes(family);

-- 2. Bekannte Familien als CHECK-Constraint (optional, kann entfernt werden wenn neue Familien nötig)
-- Vorhandene Werte: Floral, Woody, Oriental, Fresh, Citrus, Gourmand, Aquatic, Green, Spicy, Musky

-- 3. RPC: Duftrad-Daten für einen User laden
-- Zählt alle Noten-Familien der owned/favorisierten Parfums
CREATE OR REPLACE FUNCTION public.get_user_scent_wheel(p_user_id UUID)
RETURNS TABLE (
    family      TEXT,
    count       BIGINT,
    percentage  FLOAT
)
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, auth
AS $$
    WITH user_perfume_ids AS (
        -- Alle Parfum-IDs des Users (owned oder favorisiert)
        SELECT DISTINCT perfume_id
        FROM public.user_perfumes
        WHERE user_id = p_user_id
          AND (is_owned = TRUE OR is_favorite = TRUE)
    ),
    family_counts AS (
        -- Zähle wie viele verschiedene Parfums jede Duftfamilie repräsentiert
        SELECT
            n.family,
            COUNT(DISTINCT up.perfume_id) AS count
        FROM user_perfume_ids up
        JOIN public.perfume_notes pn ON pn.perfume_id = up.perfume_id
        JOIN public.notes n ON n.id = pn.note_id
        WHERE n.family IS NOT NULL
          AND n.family <> ''
        GROUP BY n.family
    ),
    total AS (
        SELECT COALESCE(SUM(count), 1) AS total
        FROM family_counts
    )
    SELECT
        fc.family,
        fc.count,
        ROUND((fc.count::FLOAT / t.total::FLOAT * 100)::NUMERIC, 1)::FLOAT AS percentage
    FROM family_counts fc
    CROSS JOIN total t
    ORDER BY fc.count DESC;
$$;

-- 4. Grants
GRANT EXECUTE ON FUNCTION public.get_user_scent_wheel(UUID) TO authenticated;
