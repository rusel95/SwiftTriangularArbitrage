//
//  Crypto.swift
//  
//
//  Created by Ruslan Popesku on 30.06.2022.
//

enum Crypto: Equatable {
    
    enum Binance: String {
        case usdt = "USDT"
        case busd = "BUSD"
    }
    
    enum WhiteBit: String {
        case usdt = "USDT"
    }
    
    enum Huobi: String {
        case usdt = "USDT_UAH"
    }
    
    case binance(Binance)
    case huobi(Huobi)
    case whiteBit(WhiteBit)
    
    var apiDescription: String {
        switch self {
        case .binance(let crypto):
            return crypto.rawValue
        case .whiteBit(let crypto):
            return crypto.rawValue
        case .huobi(let crypto):
            return crypto.rawValue
        }
    }
    
}
