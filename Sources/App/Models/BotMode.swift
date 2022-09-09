//
//  Mode.swift
//  
//
//  Created by Ruslan Popesku on 18.07.2022.
//

enum BotMode: String, Codable {
    
    case triangularArtibraging
    case alerting
    case suspended
    
    var jobInterval: Double { // in seconds
        switch self {
        case .alerting: return 60
        case .triangularArtibraging: return 5
        case .suspended: return .infinity
        }
    }
    
    var command: String {
        switch self {
        case .triangularArtibraging: return "/start_triangular_arbitrage"
        case .alerting: return "/start_alerting"
        case .suspended: return "/stop"
        }
    }
    
}
