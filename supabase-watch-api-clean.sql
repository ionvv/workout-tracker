-- Clean up old functions first
DROP FUNCTION IF EXISTS insert_session_for_device(TEXT, TEXT, TEXT, TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, JSONB, TEXT, INTEGER, INTEGER, INTEGER);
DROP FUNCTION IF EXISTS get_programs_for_device(TEXT);
DROP FUNCTION IF EXISTS get_sessions_for_device(TEXT);

-- Watch API Functions
-- Allow watch to query user data using device_id (validated via device authorization)

-- Get programs for a device (bypasses RLS)
CREATE OR REPLACE FUNCTION get_programs_for_device(p_device_id TEXT)
RETURNS SETOF programs
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    -- Verify device is authorized and get user_id
    SELECT user_id INTO v_user_id
    FROM device_auth_codes
    WHERE device_id = p_device_id
      AND authorized = true
      AND expires_at > NOW()
    ORDER BY authorized_at DESC
    LIMIT 1;
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Device not authorized';
    END IF;
    
    -- Return user's programs
    RETURN QUERY
    SELECT * FROM programs
    WHERE user_id = v_user_id
    ORDER BY created_at DESC;
END;
$$;

-- Get sessions for a device (bypasses RLS)
CREATE OR REPLACE FUNCTION get_sessions_for_device(p_device_id TEXT)
RETURNS SETOF sessions
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
BEGIN
    -- Verify device is authorized and get user_id
    SELECT user_id INTO v_user_id
    FROM device_auth_codes
    WHERE device_id = p_device_id
      AND authorized = true
      AND expires_at > NOW()
    ORDER BY authorized_at DESC
    LIMIT 1;
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Device not authorized';
    END IF;
    
    -- Return user's sessions
    RETURN QUERY
    SELECT * FROM sessions
    WHERE user_id = v_user_id
    ORDER BY start_time DESC;
END;
$$;

-- Insert session for a device (bypasses RLS)
CREATE OR REPLACE FUNCTION insert_session_for_device(
    p_device_id TEXT,
    p_session_id TEXT,
    p_program_id TEXT,
    p_day_id TEXT,
    p_day_name TEXT,
    p_start_time TEXT,
    p_end_time TEXT,
    p_exercises TEXT, -- JSON string, will be cast to JSONB
    p_notes TEXT,
    p_total_volume INTEGER,
    p_total_sets INTEGER,
    p_duration INTEGER
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_id UUID;
    v_session_uuid UUID;
BEGIN
    -- Verify device is authorized and get user_id
    SELECT user_id INTO v_user_id
    FROM device_auth_codes
    WHERE device_id = p_device_id
      AND authorized = true
      AND expires_at > NOW()
    ORDER BY authorized_at DESC
    LIMIT 1;
    
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Device not authorized';
    END IF;
    
    -- Insert session (cast TEXT params to proper types)
    INSERT INTO sessions (
        user_id,
        session_id,
        program_id,
        day_id,
        day_name,
        start_time,
        end_time,
        exercises,
        notes,
        total_volume,
        total_sets,
        duration
    ) VALUES (
        v_user_id,
        p_session_id,
        p_program_id,
        p_day_id,
        p_day_name,
        p_start_time::TIMESTAMPTZ,
        p_end_time::TIMESTAMPTZ,
        p_exercises::JSONB,
        NULLIF(p_notes, ''),
        p_total_volume,
        p_total_sets,
        p_duration
    )
    RETURNING id INTO v_session_uuid;
    
    RETURN v_session_uuid;
END;
$$;

-- Grant execute to anon (watch uses anon key)
GRANT EXECUTE ON FUNCTION get_programs_for_device(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_sessions_for_device(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION insert_session_for_device(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, INTEGER, INTEGER, INTEGER) TO anon, authenticated;

COMMENT ON FUNCTION get_programs_for_device IS 'Get programs for an authorized device (bypasses RLS)';
COMMENT ON FUNCTION get_sessions_for_device IS 'Get sessions for an authorized device (bypasses RLS)';
COMMENT ON FUNCTION insert_session_for_device IS 'Insert session for an authorized device (bypasses RLS)';
