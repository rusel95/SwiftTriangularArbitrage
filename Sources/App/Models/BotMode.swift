//
//  Mode.swift
//  
//
//  Created by Ruslan Popesku on 18.07.2022.
//

enum BotMode: String, Codable {
    
    case standartTriangularArtibraging
    case stableTriangularArbritraging
    case alerting
    case suspended
    
    var jobInterval: Double { // in seconds
        switch self {
        case .standartTriangularArtibraging:
            return 1
        case .stableTriangularArbritraging:
            return 2
        case .alerting: return .infinity
        case .suspended: return .infinity
        }
    }
    
    var command: String {
        switch self {
        case .standartTriangularArtibraging: return "/standart_triangular_arbitraging"
        case .stableTriangularArbritraging: return "/stable_triangular_arbitraging"
        case .alerting: return "/start_alerting"
        case .suspended: return "/stop"
        }
    }
    
}
