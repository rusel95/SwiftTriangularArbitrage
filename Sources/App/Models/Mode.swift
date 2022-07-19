//
//  Mode.swift
//  
//
//  Created by Ruslan Popesku on 18.07.2022.
//

enum Mode: Codable, Hashable {
    
    case trading
    case logging
    case alerting /*
                   example 1: USDT/UAH spot -> UAH Crypto to UAH fiat -> UAH fiat to USDT
                   example 2: BTC(other coint)/USDT spot price >= 2% difference to p2p market
                   example 3: Stable Coin/Stable Coin price >= 3% difference then normal level
                   */
    case suspended
    
    var jobInterval: Double { // in seconds
        switch self {
        case .trading: return 10
        case .logging: return 900
        case .alerting: return 60
        case .suspended: return .infinity
        }
    }
    
    var command: String {
        switch self {
        case .trading: return "/start_trading"
        case .logging: return "/start_logging"
        case .alerting: return "/start_alerting"
        case .suspended: return "/stop"
        }
    }
}
