//
//  ScentWheelDTO.swift
//  scentboxd
//

import Foundation

/// Ein Segment des Duftrades — Antwort der Supabase RPC `get_user_scent_wheel`.
struct ScentWheelSegment: Codable, Identifiable {
    let family: String
    let count: Int
    let percentage: Double

    var id: String { family }
}
