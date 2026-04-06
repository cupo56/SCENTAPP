-- Profile-Validierung: Username-Format serverseitig erzwingen
-- Muss mit der Client-Regex ^[a-zA-Z0-9_]{3,20}$ übereinstimmen.

ALTER TABLE profiles
  ADD CONSTRAINT profiles_username_format
    CHECK (
      username IS NULL
      OR (
        char_length(username) >= 3
        AND char_length(username) <= 20
        AND username ~ '^[a-zA-Z0-9_]{3,20}$'
      )
    );

-- RLS: User darf nur eigenes Profil ändern, alle dürfen lesen
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY IF NOT EXISTS "profiles_select_all"
  ON profiles FOR SELECT
  USING (true);

CREATE POLICY IF NOT EXISTS "profiles_insert_own"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY IF NOT EXISTS "profiles_update_own"
  ON profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);
