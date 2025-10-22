-- =============================================================================
-- STREAMLINED SMART SWITCH DATABASE - SIMPLIFIED & EFFICIENT
-- Clean hierarchy: User → Home → Room → Board → Switch → Timer
-- Custom ID patterns with username prefixes
-- Minimal columns, maximum efficiency
-- =============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================================================
-- 1. CLEAN SLATE - DROP EXISTING OBJECTS
-- =============================================================================

-- Drop existing tables in correct order
DROP TABLE IF EXISTS switch_logs CASCADE;
DROP TABLE IF EXISTS timers CASCADE;
DROP TABLE IF EXISTS switches CASCADE;
DROP TABLE IF EXISTS boards CASCADE;
DROP TABLE IF EXISTS rooms CASCADE;
DROP TABLE IF EXISTS home_shares CASCADE;
DROP TABLE IF EXISTS homes CASCADE;
DROP TABLE IF EXISTS user_profiles CASCADE;

-- Drop functions and triggers
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;

-- =============================================================================
-- 2. CREATE STREAMLINED TABLES
-- =============================================================================

-- User profiles - Essential info only
CREATE TABLE user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE NOT NULL,
    location TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Homes - User-owned with custom ID pattern
CREATE TABLE homes (
    id TEXT PRIMARY KEY, -- Format: USERNAME_home_1, USERNAME_home_2, etc.
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    location TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Rooms - Home-scoped with custom ID pattern
CREATE TABLE rooms (
    id TEXT PRIMARY KEY, -- Format: USERNAME_home_1_room_1, etc.
    home_id TEXT NOT NULL REFERENCES homes(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    icon TEXT DEFAULT 'meeting_room',
    display_order INTEGER DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Home sharing - Simple sharing mechanism
CREATE TABLE home_shares (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    home_id TEXT NOT NULL REFERENCES homes(id) ON DELETE CASCADE,
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    shared_with_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    can_control BOOLEAN DEFAULT TRUE,
    shared_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(home_id, shared_with_id)
);

-- Boards - Hardware devices with hardcoded IDs
CREATE TABLE boards (
    id TEXT PRIMARY KEY, -- Hardcoded in firmware (e.g., "BOARD_001", "BOARD_002")
    home_id TEXT REFERENCES homes(id) ON DELETE SET NULL,
    room_id TEXT REFERENCES rooms(id) ON DELETE SET NULL,
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'offline' CHECK (status IN ('online', 'offline')),
    mac_address TEXT,
    last_online TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Switches - Board-attached with custom ID pattern
CREATE TABLE switches (
    id TEXT PRIMARY KEY, -- Format: BOARD_001_switch_1, etc.
    board_id TEXT NOT NULL REFERENCES boards(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'light' CHECK (type IN ('light', 'fan', 'ac', 'heater', 'tv', 'speaker', 'plug', 'motor', 'pump', 'door', 'window', 'curtain')),
    position INTEGER NOT NULL DEFAULT 0,
    state BOOLEAN NOT NULL DEFAULT FALSE,
    is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
    last_state_change TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(board_id, position)
);

-- Timer types enum
CREATE TYPE timer_type AS ENUM ('scheduled', 'prescheduled', 'countdown');

-- Timers table
CREATE TABLE timers (
    id TEXT PRIMARY KEY,
    switch_id TEXT NOT NULL REFERENCES switches(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    time TEXT NOT NULL,
    action TEXT NOT NULL DEFAULT 'on',
    state BOOLEAN NOT NULL DEFAULT true,
    is_enabled BOOLEAN NOT NULL DEFAULT true,
    type timer_type NOT NULL DEFAULT 'scheduled',
    days TEXT[] DEFAULT '{}',
    scheduled_date TIMESTAMP WITH TIME ZONE,
    last_run TIMESTAMP WITH TIME ZONE,
    next_run TIMESTAMP WITH TIME ZONE,
    created_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Switch activity logs - Track who did what
CREATE TABLE switch_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    switch_id TEXT NOT NULL REFERENCES switches(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    action TEXT NOT NULL, -- 'turned_on', 'turned_off'
    triggered_by TEXT DEFAULT 'manual', -- 'manual', 'timer', 'physical'
    user_name TEXT, -- Store username for display in logs
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =============================================================================
-- 3. CREATE PERFORMANCE INDEXES
-- =============================================================================

-- User profiles
CREATE INDEX idx_user_profiles_username ON user_profiles(username);
CREATE INDEX idx_user_profiles_email ON user_profiles(email);

-- Homes
CREATE INDEX idx_homes_user_id ON homes(user_id);
CREATE INDEX idx_homes_is_active ON homes(is_active);

-- Rooms
CREATE INDEX idx_rooms_home_id ON rooms(home_id);
CREATE INDEX idx_rooms_display_order ON rooms(display_order);

-- Home shares
CREATE INDEX idx_home_shares_home_id ON home_shares(home_id);
CREATE INDEX idx_home_shares_shared_with_id ON home_shares(shared_with_id);

-- Boards
CREATE INDEX idx_boards_owner_id ON boards(owner_id);
CREATE INDEX idx_boards_home_id ON boards(home_id);
CREATE INDEX idx_boards_room_id ON boards(room_id);
CREATE INDEX idx_boards_status ON boards(status);

-- Switches
CREATE INDEX idx_switches_board_id ON switches(board_id);
CREATE INDEX idx_switches_position ON switches(board_id, position);

-- Timers
CREATE INDEX idx_timers_switch_id ON timers(switch_id);
CREATE INDEX idx_timers_user_id ON timers(user_id);
CREATE INDEX idx_timers_type ON timers(type);
CREATE INDEX idx_timers_is_enabled ON timers(is_enabled);
CREATE INDEX idx_timers_next_run ON timers(next_run);
CREATE INDEX idx_timers_scheduled_date ON timers(scheduled_date);

-- Switch logs
CREATE INDEX idx_switch_logs_switch_id ON switch_logs(switch_id);
CREATE INDEX idx_switch_logs_user_id ON switch_logs(user_id);
CREATE INDEX idx_switch_logs_created_at ON switch_logs(created_at);

-- =============================================================================
-- 4. ENABLE ROW LEVEL SECURITY
-- =============================================================================

ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE homes ENABLE ROW LEVEL SECURITY;
ALTER TABLE rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE home_shares ENABLE ROW LEVEL SECURITY;
ALTER TABLE boards ENABLE ROW LEVEL SECURITY;
ALTER TABLE switches ENABLE ROW LEVEL SECURITY;
ALTER TABLE timers ENABLE ROW LEVEL SECURITY;
ALTER TABLE switch_logs ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- 5. CREATE SIMPLE RLS POLICIES
-- =============================================================================

-- User profiles - only own data
CREATE POLICY "user_profiles_own" ON user_profiles
    FOR ALL USING (id = auth.uid());

-- Homes - owner or shared access
CREATE POLICY "homes_owner" ON homes
    FOR ALL USING (user_id = auth.uid());

CREATE POLICY "homes_shared" ON homes
    FOR SELECT USING (
        id IN (SELECT home_id FROM home_shares WHERE shared_with_id = auth.uid())
    );

-- Rooms - access through home ownership or sharing
CREATE POLICY "rooms_owner" ON rooms
    FOR ALL USING (
        home_id IN (SELECT id FROM homes WHERE user_id = auth.uid())
    );

CREATE POLICY "rooms_shared" ON rooms
    FOR SELECT USING (
        home_id IN (SELECT home_id FROM home_shares WHERE shared_with_id = auth.uid())
    );

-- Home shares - owners can manage, shared users can view
CREATE POLICY "home_shares_owner" ON home_shares
    FOR ALL USING (owner_id = auth.uid());

CREATE POLICY "home_shares_shared" ON home_shares
    FOR SELECT USING (shared_with_id = auth.uid());

-- Boards - owner access only (assignment happens during setup)
CREATE POLICY "boards_owner" ON boards
    FOR ALL USING (owner_id = auth.uid());

-- Switches - through board ownership
CREATE POLICY "switches_owner" ON switches
    FOR ALL USING (
        board_id IN (SELECT id FROM boards WHERE owner_id = auth.uid())
    );

-- Shared switch control - users with home access can control switches
CREATE POLICY "switches_shared_control" ON switches
    FOR UPDATE USING (
        board_id IN (
            SELECT b.id FROM boards b 
            JOIN home_shares hs ON b.home_id = hs.home_id 
            WHERE hs.shared_with_id = auth.uid() AND hs.can_control = true
        )
    );

-- Timers - owner or shared access
CREATE POLICY "timers_owner" ON timers
    FOR ALL USING (user_id = auth.uid());

-- Switch logs - owner or shared access can view
CREATE POLICY "switch_logs_owner" ON switch_logs
    FOR SELECT USING (
        switch_id IN (
            SELECT s.id FROM switches s
            JOIN boards b ON s.board_id = b.id
            WHERE b.owner_id = auth.uid()
        )
    );

CREATE POLICY "switch_logs_shared" ON switch_logs
    FOR SELECT USING (
        switch_id IN (
            SELECT s.id FROM switches s
            JOIN boards b ON s.board_id = b.id
            JOIN home_shares hs ON b.home_id = hs.home_id
            WHERE hs.shared_with_id = auth.uid()
        )
    );

-- Allow system to insert logs
CREATE POLICY "switch_logs_insert" ON switch_logs
    FOR INSERT WITH CHECK (true);

-- =============================================================================
-- 6. CREATE UTILITY FUNCTIONS
-- =============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Auto-create user profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_profiles (
        id, 
        username, 
        email,
        location,
        created_at
    )
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'location', ''),
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        email = EXCLUDED.email;
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to generate home ID
CREATE OR REPLACE FUNCTION generate_home_id(username TEXT)
RETURNS TEXT AS $$
DECLARE
    home_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO home_count 
    FROM homes h
    JOIN user_profiles u ON h.user_id = u.id
    WHERE u.username = username;
    
    RETURN UPPER(username) || '_home_' || (home_count + 1);
END;
$$ LANGUAGE plpgsql;

-- Function to generate room ID
CREATE OR REPLACE FUNCTION generate_room_id(home_id TEXT)
RETURNS TEXT AS $$
DECLARE
    room_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO room_count FROM rooms WHERE home_id = home_id;
    RETURN home_id || '_room_' || (room_count + 1);
END;
$$ LANGUAGE plpgsql;

-- Function to log switch actions
CREATE OR REPLACE FUNCTION log_switch_action()
RETURNS TRIGGER AS $$
DECLARE
    username TEXT;
BEGIN
    -- Get username for logging
    SELECT up.username INTO username
    FROM user_profiles up
    WHERE up.id = auth.uid();
    
    -- Only log if state actually changed
    IF OLD.state != NEW.state THEN
        INSERT INTO switch_logs (
            switch_id,
            user_id,
            action,
            triggered_by,
            user_name,
            created_at
        ) VALUES (
            NEW.id,
            auth.uid(),
            CASE WHEN NEW.state THEN 'turned_on' ELSE 'turned_off' END,
            'manual',
            username,
            NOW()
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================================================
-- 7. ADDITIONAL TIMER FUNCTIONS
-- =============================================================================

-- Function to calculate next run time for scheduled timers
CREATE OR REPLACE FUNCTION calculate_next_run(
    timer_type timer_type,
    timer_time TEXT,
    days_array TEXT[],
    scheduled_date TIMESTAMP WITH TIME ZONE DEFAULT NULL
) RETURNS TIMESTAMP WITH TIME ZONE AS $$
DECLARE
    next_run TIMESTAMP WITH TIME ZONE;
    time_parts TEXT[];
    hour_val INTEGER;
    minute_val INTEGER;
    day_name TEXT;
    days_of_week TEXT[] := ARRAY['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
    target_day INTEGER;
    current_dow INTEGER;
    days_ahead INTEGER;
BEGIN
    CASE timer_type
        WHEN 'prescheduled' THEN
            -- For prescheduled timers, next run is the scheduled date
            next_run := scheduled_date;
            
        WHEN 'scheduled' THEN
            -- Parse time (HH:MM format)
            time_parts := string_to_array(timer_time, ':');
            hour_val := time_parts[1]::INTEGER;
            minute_val := time_parts[2]::INTEGER;
            
            -- Find the next occurrence based on selected days
            next_run := NULL;
            current_dow := EXTRACT(dow FROM now());
            
            FOREACH day_name IN ARRAY days_array
            LOOP
                -- Convert day name to number (0=Sunday, 1=Monday, etc.)
                target_day := array_position(days_of_week, lower(day_name)) - 1;
                
                -- Calculate days ahead
                IF target_day >= current_dow THEN
                    days_ahead := target_day - current_dow;
                ELSE
                    days_ahead := 7 - (current_dow - target_day);
                END IF;
                
                -- If it's today, check if time hasn't passed
                IF days_ahead = 0 THEN
                    IF EXTRACT(hour FROM now()) < hour_val OR 
                       (EXTRACT(hour FROM now()) = hour_val AND EXTRACT(minute FROM now()) < minute_val) THEN
                        next_run := date_trunc('day', now()) + INTERVAL '1 hour' * hour_val + INTERVAL '1 minute' * minute_val;
                        EXIT;
                    END IF;
                ELSE
                    -- Future day
                    next_run := date_trunc('day', now()) + INTERVAL '1 day' * days_ahead + 
                               INTERVAL '1 hour' * hour_val + INTERVAL '1 minute' * minute_val;
                    EXIT;
                END IF;
            END LOOP;
            
            -- If no next run found for this week, find next week
            IF next_run IS NULL AND array_length(days_array, 1) > 0 THEN
                day_name := days_array[1];
                target_day := array_position(days_of_week, lower(day_name)) - 1;
                days_ahead := 7 - current_dow + target_day;
                next_run := date_trunc('day', now()) + INTERVAL '1 day' * days_ahead + 
                           INTERVAL '1 hour' * hour_val + INTERVAL '1 minute' * minute_val;
            END IF;
            
        WHEN 'countdown' THEN
            -- For countdown timers, next run is immediate (handled by app)
            next_run := now();
    END CASE;
    
    RETURN next_run;
END;
$$ LANGUAGE plpgsql;

-- Function to update next_run when timer is created or modified
CREATE OR REPLACE FUNCTION update_timer_next_run()
RETURNS TRIGGER AS $$
BEGIN
    NEW.next_run := calculate_next_run(NEW.type, NEW.time, NEW.days, NEW.scheduled_date);
    NEW.updated_at := now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update next_run
CREATE TRIGGER update_timer_next_run_trigger
    BEFORE INSERT OR UPDATE ON timers
    FOR EACH ROW EXECUTE FUNCTION update_timer_next_run();

-- =============================================================================
-- 8. TRIGGERS
-- =============================================================================

-- Auto-create user profile
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Updated timestamp triggers
CREATE TRIGGER update_homes_updated_at 
    BEFORE UPDATE ON homes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_rooms_updated_at 
    BEFORE UPDATE ON rooms
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_boards_updated_at 
    BEFORE UPDATE ON boards
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_switches_updated_at 
    BEFORE UPDATE ON switches
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_timers_updated_at 
    BEFORE UPDATE ON timers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Log switch state changes
CREATE TRIGGER log_switch_state_changes
    AFTER UPDATE ON switches
    FOR EACH ROW EXECUTE FUNCTION log_switch_action();

-- =============================================================================
-- 9. GRANT PERMISSIONS
-- =============================================================================

GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO authenticated;

-- =============================================================================
-- 10. VERIFICATION
-- =============================================================================

SELECT 
    'STREAMLINED Database Setup Complete!' as status,
    'Custom ID patterns implemented' as id_patterns,
    'User → Home → Room → Board → Switch → Timer hierarchy' as hierarchy,
    'Home sharing with activity logging' as sharing,
    'Minimal columns for maximum efficiency' as design;