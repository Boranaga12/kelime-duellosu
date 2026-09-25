-- ====================================================================
-- KELİME DUELLOSU - SUPABASE VERİTABANI ŞEMASI (SQL MIGRATION)
-- Bu dosyayı Supabase Dashboard -> SQL Editor kısmına yapıştırıp "Run" yapınız.
-- ====================================================================

-- 1. ODA YÖNETİMİ TABLOSU (game_rooms)
CREATE TABLE IF NOT EXISTS public.game_rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_code TEXT UNIQUE NOT NULL,
    host_name TEXT NOT NULL,
    host_id TEXT NOT NULL,
    guest_name TEXT,
    guest_id TEXT,
    status TEXT NOT NULL DEFAULT 'waiting', -- waiting, in_progress, finished
    room_data JSONB,                        -- Özel oda ayarları, takımlar, oyuncular
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Eski odaların sorgusunu hızlandırmak için indeksler
CREATE INDEX IF NOT EXISTS idx_game_rooms_status ON public.game_rooms(status);
CREATE INDEX IF NOT EXISTS idx_game_rooms_code ON public.game_rooms(room_code);
CREATE INDEX IF NOT EXISTS idx_game_rooms_created ON public.game_rooms(created_at DESC);

-- 2. KULLANICI PROFİLLERİ (app_users)
CREATE TABLE IF NOT EXISTS public.app_users (
    id TEXT PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT,
    tag TEXT NOT NULL,
    avatar TEXT DEFAULT '👑',
    title TEXT DEFAULT 'Çaylak Düellocu',
    email TEXT UNIQUE,
    email_verified BOOLEAN DEFAULT FALSE,
    trophies INTEGER DEFAULT 1200,
    level INTEGER DEFAULT 1,
    progress_data JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_app_users_username ON public.app_users(username);
CREATE INDEX IF NOT EXISTS idx_app_users_tag ON public.app_users(tag);
CREATE INDEX IF NOT EXISTS idx_app_users_email ON public.app_users(email);

-- 3. ARKADAŞLIK SİSTEMİ (app_friends)
CREATE TABLE IF NOT EXISTS public.app_friends (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id TEXT NOT NULL,
    friend_id TEXT NOT NULL,
    status TEXT DEFAULT 'accepted',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_app_friends_user ON public.app_friends(user_id);
CREATE INDEX IF NOT EXISTS idx_app_friends_friend ON public.app_friends(friend_id);

-- 4. YAPAY ZEKA ÖĞRENİLMİŞ KELİME HAVUZU (learned_category_words)
CREATE TABLE IF NOT EXISTS public.learned_category_words (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_id TEXT NOT NULL,
    word TEXT NOT NULL,
    status TEXT DEFAULT 'approved',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_learned_words_cat ON public.learned_category_words(category_id);

-- ====================================================================
-- ROW LEVEL SECURITY (RLS) POLİTİKALARI (Anonim Kullanıcı İzinleri)
-- ====================================================================

-- game_rooms tablosu için tam erişim (Herkes oda görebilir, kurabilir ve katılabilir)
ALTER TABLE public.game_rooms ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access for game_rooms" ON public.game_rooms;
CREATE POLICY "Public access for game_rooms" ON public.game_rooms
    FOR ALL USING (true) WITH CHECK (true);

-- app_users tablosu için okuma ve yazma erişimi
ALTER TABLE public.app_users ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access for app_users" ON public.app_users;
CREATE POLICY "Public access for app_users" ON public.app_users
    FOR ALL USING (true) WITH CHECK (true);

-- app_friends tablosu için tam erişim
ALTER TABLE public.app_friends ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access for app_friends" ON public.app_friends;
CREATE POLICY "Public access for app_friends" ON public.app_friends
    FOR ALL USING (true) WITH CHECK (true);

-- learned_category_words tablosu için tam erişim
ALTER TABLE public.learned_category_words ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Public access for learned_category_words" ON public.learned_category_words;
CREATE POLICY "Public access for learned_category_words" ON public.learned_category_words
    FOR ALL USING (true) WITH CHECK (true);

-- ====================================================================
-- REALTIME YAYINI (game_rooms tablosunun anlık dinlenebilmesi için)
-- ====================================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND tablename = 'game_rooms'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.game_rooms;
    END IF;
END $$;
