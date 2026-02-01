import Foundation

// RPC parameter structs for Supabase calls
// Defined in separate file to avoid MainActor isolation issues

struct GetProgramsParams: Encodable, Sendable {
    let p_device_id: String
}

struct GetSessionsParams: Encodable, Sendable {
    let p_device_id: String
}

struct SaveSessionParams: Encodable, Sendable {
    let p_device_id: String
    let p_session_id: String
    let p_program_id: String
    let p_day_id: String
    let p_day_name: String
    let p_start_time: String
    let p_end_time: String
    let p_exercises: String
    let p_notes: String?
    let p_total_volume: Int
    let p_total_sets: Int
    let p_duration: Int
}
