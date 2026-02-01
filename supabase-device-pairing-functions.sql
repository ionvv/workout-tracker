-- PostgreSQL Functions for Device Pairing API
-- These are called via Supabase RPC from watch app and web app

-- Function to request a pairing code (called by watch)
CREATE OR REPLACE FUNCTION request_pairing_code(device_id TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_code TEXT;
    v_expires_at TIMESTAMPTZ;
    v_result JSON;
BEGIN
    -- Generate random 6-digit code
    v_code := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
    
    -- Set expiration to 3 minutes from now
    v_expires_at := NOW() + INTERVAL '3 minutes';
    
    -- Insert new pairing code
    INSERT INTO device_auth_codes (code, device_id, expires_at)
    VALUES (v_code, device_id, v_expires_at)
    RETURNING JSON_BUILD_OBJECT(
        'code', code,
        'expires_at', expires_at
    ) INTO v_result;
    
    RETURN v_result;
END;
$$;

-- Function to check if device is authorized (called by watch - polling)
CREATE OR REPLACE FUNCTION check_device_authorization(device_id TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_record RECORD;
    v_result JSON;
BEGIN
    -- Find most recent authorized code for this device
    SELECT * INTO v_record
    FROM device_auth_codes
    WHERE device_auth_codes.device_id = check_device_authorization.device_id
      AND authorized = true
      AND expires_at > NOW()
    ORDER BY created_at DESC
    LIMIT 1;
    
    IF FOUND THEN
        v_result := JSON_BUILD_OBJECT(
            'authorized', true,
            'user_id', v_record.user_id,
            'authorized_at', v_record.authorized_at
        );
    ELSE
        v_result := JSON_BUILD_OBJECT(
            'authorized', false,
            'user_id', NULL
        );
    END IF;
    
    RETURN v_result;
END;
$$;

-- Function to authorize a pairing code (called by web app)
CREATE OR REPLACE FUNCTION authorize_pairing_code(p_code TEXT, p_user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_code_id UUID;
    v_result JSON;
BEGIN
    -- Check if code exists and is valid
    SELECT id INTO v_code_id
    FROM device_auth_codes
    WHERE code = p_code
      AND expires_at > NOW()
      AND authorized = false
    LIMIT 1;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid or expired pairing code';
    END IF;
    
    -- Update code to authorized
    UPDATE device_auth_codes
    SET 
        user_id = p_user_id,
        authorized = true,
        authorized_at = NOW()
    WHERE id = v_code_id;
    
    v_result := JSON_BUILD_OBJECT(
        'success', true,
        'message', 'Device paired successfully'
    );
    
    RETURN v_result;
END;
$$;

-- Grant execute permissions to anon and authenticated users
GRANT EXECUTE ON FUNCTION request_pairing_code(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION check_device_authorization(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION authorize_pairing_code(TEXT, UUID) TO authenticated;

COMMENT ON FUNCTION request_pairing_code IS 'Generate a new 6-digit pairing code for device authentication';
COMMENT ON FUNCTION check_device_authorization IS 'Check if a device has been authorized (polling endpoint)';
COMMENT ON FUNCTION authorize_pairing_code IS 'Authorize a pairing code with user credentials';
