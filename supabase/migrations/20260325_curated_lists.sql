-- Migration: Curated Lists (Feature 2.6)
-- Erstellt: 2026-03-25

-- ─── TABELLEN ────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS lists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL CHECK (char_length(trim(name)) > 0 AND char_length(name) <= 100),
    description TEXT CHECK (description IS NULL OR char_length(description) <= 500),
    is_public BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS list_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    list_id UUID NOT NULL REFERENCES lists(id) ON DELETE CASCADE,
    perfume_id UUID NOT NULL REFERENCES perfumes(id) ON DELETE CASCADE,
    added_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(list_id, perfume_id)
);

-- ─── INDIZES ─────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_lists_user_id ON lists(user_id);
CREATE INDEX IF NOT EXISTS idx_list_items_list_id ON list_items(list_id);
CREATE INDEX IF NOT EXISTS idx_list_items_perfume_id ON list_items(perfume_id);

-- ─── RLS ─────────────────────────────────────────────────────────────────────

ALTER TABLE lists ENABLE ROW LEVEL SECURITY;
ALTER TABLE list_items ENABLE ROW LEVEL SECURITY;

-- lists: Eigene Listen lesen/schreiben, öffentliche Listen lesen
CREATE POLICY "lists_owner_all" ON lists
    FOR ALL
    TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "lists_public_read" ON lists
    FOR SELECT
    TO authenticated
    USING (is_public = true);

-- list_items: Zugriff nur wenn man die Liste besitzt oder sie öffentlich ist
CREATE POLICY "list_items_owner_all" ON list_items
    FOR ALL
    TO authenticated
    USING (
        list_id IN (
            SELECT id FROM lists WHERE user_id = auth.uid()
        )
    )
    WITH CHECK (
        list_id IN (
            SELECT id FROM lists WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "list_items_public_read" ON list_items
    FOR SELECT
    TO authenticated
    USING (
        list_id IN (
            SELECT id FROM lists WHERE is_public = true
        )
    );

-- ─── HILFSFUNKTION: Anzahl Items pro Liste ───────────────────────────────────

CREATE OR REPLACE FUNCTION get_list_item_count(p_list_id UUID)
RETURNS BIGINT
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT COUNT(*) FROM list_items WHERE list_id = p_list_id;
$$;

-- ─── RPC: Öffentliche Listen eines Users mit Item-Anzahl ─────────────────────

CREATE OR REPLACE FUNCTION get_public_lists(p_user_id UUID)
RETURNS TABLE (
    id UUID,
    user_id UUID,
    name TEXT,
    description TEXT,
    is_public BOOLEAN,
    created_at TIMESTAMPTZ,
    item_count BIGINT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT
        l.id,
        l.user_id,
        l.name,
        l.description,
        l.is_public,
        l.created_at,
        COUNT(li.id) AS item_count
    FROM lists l
    LEFT JOIN list_items li ON li.list_id = l.id
    WHERE l.user_id = p_user_id
      AND l.is_public = true
    GROUP BY l.id
    ORDER BY l.created_at DESC;
$$;

-- ─── RPC: Eigene Listen mit Item-Anzahl ──────────────────────────────────────

CREATE OR REPLACE FUNCTION get_my_lists()
RETURNS TABLE (
    id UUID,
    user_id UUID,
    name TEXT,
    description TEXT,
    is_public BOOLEAN,
    created_at TIMESTAMPTZ,
    item_count BIGINT
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT
        l.id,
        l.user_id,
        l.name,
        l.description,
        l.is_public,
        l.created_at,
        COUNT(li.id) AS item_count
    FROM lists l
    LEFT JOIN list_items li ON li.list_id = l.id
    WHERE l.user_id = auth.uid()
    GROUP BY l.id
    ORDER BY l.created_at DESC;
$$;
