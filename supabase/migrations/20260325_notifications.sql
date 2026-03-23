-- Push-Notifications: device_tokens + notification_preferences
-- Stand: 25.03.2026

-- =========================================================
-- TABELLEN
-- =========================================================

CREATE TABLE public.device_tokens (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL,
    token text NOT NULL,
    platform text NOT NULL DEFAULT 'ios',
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT device_tokens_pkey PRIMARY KEY (id),
    CONSTRAINT device_tokens_user_token_key UNIQUE (user_id, token),
    CONSTRAINT device_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

CREATE TABLE public.notification_preferences (
    user_id uuid NOT NULL,
    new_reviews boolean NOT NULL DEFAULT true,
    review_likes boolean NOT NULL DEFAULT true,
    similar_added boolean NOT NULL DEFAULT false,
    community_updates boolean NOT NULL DEFAULT false,
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT notification_preferences_pkey PRIMARY KEY (user_id),
    CONSTRAINT notification_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

-- =========================================================
-- ROW LEVEL SECURITY
-- =========================================================

ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Eigene Tokens verwalten" ON public.device_tokens
    FOR ALL USING (auth.uid() = user_id);

ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Eigene Präferenzen verwalten" ON public.notification_preferences
    FOR ALL USING (auth.uid() = user_id);

-- =========================================================
-- RPCs (SECURITY DEFINER, damit client-seitig keine user_id angegeben werden muss)
-- =========================================================

CREATE OR REPLACE FUNCTION public.upsert_device_token(p_token text)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $$
    INSERT INTO public.device_tokens (user_id, token)
    VALUES (auth.uid(), p_token)
    ON CONFLICT (user_id, token) DO NOTHING;
$$;

CREATE OR REPLACE FUNCTION public.delete_device_token(p_token text)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
AS $$
    DELETE FROM public.device_tokens
    WHERE user_id = auth.uid() AND token = p_token;
$$;

-- =========================================================
-- TRIGGER: Benachrichtigung bei neuer Review
-- Ruft die Edge Function "send-notification" per pg_net auf.
--
-- SETUP ERFORDERLICH (einmalig im Supabase SQL-Editor ausführen):
--   ALTER DATABASE postgres SET app.supabase_url = 'https://DEIN-PROJEKT.supabase.co';
--   ALTER DATABASE postgres SET app.service_role_key = 'DEIN-SERVICE-ROLE-KEY';
-- =========================================================

CREATE OR REPLACE FUNCTION public.notify_on_new_review()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_owner_id uuid;
    v_actor_name text;
    v_perfume_name text;
BEGIN
    SELECT username INTO v_actor_name FROM public.profiles WHERE id = NEW.user_id;
    SELECT name INTO v_perfume_name FROM public.perfumes WHERE id = NEW.perfume_id;

    FOR v_owner_id IN
        SELECT DISTINCT up.user_id
        FROM public.user_perfumes up
        WHERE up.perfume_id = NEW.perfume_id
          AND up.user_id != NEW.user_id
          AND (up.is_owned = true OR up.is_favorite = true)
    LOOP
        PERFORM net.http_post(
            url     := current_setting('app.supabase_url') || '/functions/v1/send-notification',
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer ' || current_setting('app.service_role_key')
            ),
            body    := jsonb_build_object(
                'type',        'new_review',
                'targetUserId', v_owner_id,
                'perfumeId',   NEW.perfume_id,
                'reviewId',    NEW.id,
                'actorName',   COALESCE(v_actor_name, 'Jemand'),
                'perfumeName', COALESCE(v_perfume_name, 'einem Parfum')
            )::text
        );
    END LOOP;

    RETURN NEW;
END;
$$;

CREATE TRIGGER on_new_review
    AFTER INSERT ON public.reviews
    FOR EACH ROW EXECUTE FUNCTION public.notify_on_new_review();

-- =========================================================
-- TRIGGER: Benachrichtigung bei Review-Like
-- =========================================================

CREATE OR REPLACE FUNCTION public.notify_on_review_like()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_review_owner_id uuid;
    v_actor_name text;
    v_perfume_name text;
    v_perfume_id uuid;
BEGIN
    SELECT r.user_id, r.perfume_id INTO v_review_owner_id, v_perfume_id
    FROM public.reviews r WHERE r.id = NEW.review_id;

    IF v_review_owner_id IS NULL OR v_review_owner_id = NEW.user_id THEN
        RETURN NEW;
    END IF;

    SELECT username INTO v_actor_name FROM public.profiles WHERE id = NEW.user_id;
    SELECT name INTO v_perfume_name FROM public.perfumes WHERE id = v_perfume_id;

    PERFORM net.http_post(
        url     := current_setting('app.supabase_url') || '/functions/v1/send-notification',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || current_setting('app.service_role_key')
        ),
        body    := jsonb_build_object(
            'type',        'review_like',
            'targetUserId', v_review_owner_id,
            'perfumeId',   v_perfume_id,
            'reviewId',    NEW.review_id,
            'actorName',   COALESCE(v_actor_name, 'Jemand'),
            'perfumeName', COALESCE(v_perfume_name, 'einem Parfum')
        )::text
    );

    RETURN NEW;
END;
$$;

CREATE TRIGGER on_review_like
    AFTER INSERT ON public.review_likes
    FOR EACH ROW EXECUTE FUNCTION public.notify_on_review_like();
