//
//  Mode.swift
//  
//
//  Created by Ruslan Popesku on 18.07.2022.
//

enum BotMode: Codable, Hashable {
    
    case whereToBuy
    case trading
    case alerting /*
                   example 1: USDT/UAH spot -> UAH Crypto to UAH fiat -> UAH fiat to USDT
                   example 2: BTC(other coint)/USDT spot price >= 2% difference to p2p market
                   example 3: Stable Coin/Stable Coin price >= 3% difference then normal level
                   */
    case arbitraging
    case logging
    case suspended
    
    var jobInterval: Double { // in seconds
        switch self {
        case .trading: return 15
        case .alerting: return 60
        case .arbitraging: return 15
        case .logging: return 900
        case .suspended, .whereToBuy: return .infinity
        }
    }
    
    var command: String {
        switch self {
        case .whereToBuy: return "/where_to_buy"
        case .trading: return "/start_trading"
        case .alerting: return "/start_alerting"
        case .arbitraging: return "/start_arbitraging"
        case .logging: return "/start_logging"
        case .suspended: return "/stop"
        }
    }
}
