-- Device Auth Codes Table for Watch Pairing
-- Allows watches to generate codes and web app to authorize them

CREATE TABLE IF NOT EXISTS device_auth_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,
    device_id TEXT NOT NULL, -- Unique identifier from watch (e.g., UUID)
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    authorized BOOLEAN NOT NULL DEFAULT false,
    authorized_at TIMESTAMPTZ
);

-- Index for fast code lookups
CREATE INDEX IF NOT EXISTS idx_device_auth_codes_code ON device_auth_codes(code);

-- Index for device_id lookups (watch polling)
CREATE INDEX IF NOT EXISTS idx_device_auth_codes_device_id ON device_auth_codes(device_id);

-- Clean up expired codes automatically (optional, manual cleanup also works)
CREATE INDEX IF NOT EXISTS idx_device_auth_codes_expires_at ON device_auth_codes(expires_at);

-- RLS Policies
ALTER TABLE device_auth_codes ENABLE ROW LEVEL SECURITY;

-- Anyone can create a pairing code (watch can request without auth)
CREATE POLICY "Allow anonymous code creation" ON device_auth_codes
    FOR INSERT
    TO anon
    WITH CHECK (true);

-- Anyone can read their own device's code status (for polling)
CREATE POLICY "Allow device polling" ON device_auth_codes
    FOR SELECT
    TO anon
    USING (true);

-- Authenticated users can authorize codes
CREATE POLICY "Allow users to authorize codes" ON device_auth_codes
    FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- Auto-cleanup function (runs periodically to delete expired codes)
CREATE OR REPLACE FUNCTION cleanup_expired_device_codes()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    DELETE FROM device_auth_codes
    WHERE expires_at < now() AND authorized = false;
END;
$$;

COMMENT ON TABLE device_auth_codes IS 'Stores temporary pairing codes for device authentication (Apple Watch, etc.)';
COMMENT ON COLUMN device_auth_codes.code IS '6-digit pairing code displayed on device';
COMMENT ON COLUMN device_auth_codes.device_id IS 'Unique device identifier (UUID from watch)';
COMMENT ON COLUMN device_auth_codes.expires_at IS 'Code expiration time (typically 2-3 minutes from creation)';
