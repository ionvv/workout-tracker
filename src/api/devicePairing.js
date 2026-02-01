// Device Pairing API
// Handles Apple Watch (and other device) pairing via temporary codes

import { supabase } from '../utils/supabase.js'

/**
 * Generate a random 6-digit pairing code
 */
function generatePairingCode() {
  return Math.floor(100000 + Math.random() * 900000).toString()
}

/**
 * Request a new pairing code (called by watch app)
 * @param {string} deviceId - Unique device identifier (UUID from watch)
 * @returns {object} { code, expiresAt }
 */
export async function requestPairingCode(deviceId) {
  const { data, error } = await supabase.rpc('request_pairing_code', {
    device_id: deviceId
  })

  if (error) {
    console.error('Error creating pairing code:', error)
    throw error
  }

  return {
    code: data.code,
    expiresAt: data.expires_at
  }
}

/**
 * Check if a device has been authorized (called by watch app - polling)
 * @param {string} deviceId - Unique device identifier
 * @returns {object} { authorized, userId, authorizedAt }
 */
export async function checkDeviceAuthorization(deviceId) {
  const { data, error } = await supabase.rpc('check_device_authorization', {
    device_id: deviceId
  })

  if (error) {
    console.error('Error checking authorization:', error)
    return { authorized: false }
  }

  return {
    authorized: data.authorized || false,
    userId: data.user_id,
    authorizedAt: data.authorized_at
  }
}

/**
 * Authorize a pairing code (called by web app after user login)
 * @param {string} code - 6-digit pairing code from watch
 * @param {string} userId - User ID from authenticated session
 * @returns {boolean} Success
 */
export async function authorizePairingCode(code, userId) {
  const { data, error } = await supabase.rpc('authorize_pairing_code', {
    p_code: code,
    p_user_id: userId
  })

  if (error) {
    console.error('Error authorizing code:', error)
    throw new Error(error.message || 'Invalid or expired pairing code')
  }

  return data.success || true
}

/**
 * Cleanup expired codes (optional - can be called manually or via cron)
 */
export async function cleanupExpiredCodes() {
  const { error } = await supabase
    .from('device_auth_codes')
    .delete()
    .lt('expires_at', new Date().toISOString())
    .eq('authorized', false)

  if (error) {
    console.error('Error cleaning up codes:', error)
    throw error
  }

  return true
}
