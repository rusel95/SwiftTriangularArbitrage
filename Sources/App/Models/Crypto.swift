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
        case btc = "BTC"
        case bnb = "BNB"
        
        var apiDescription: String {
            return self.rawValue
        }
    }
    
    enum WhiteBit: String {
        case usdt = "USDT"
    }
    
    enum Huobi: String {
        case usdt = "USDT_UAH"
        
        var description: String {
            switch self {
            case .usdt: return "USDT"
            }
        }
    }
    
    enum EXMO: String {
        case usdt = "USDT"
    }
    
    case binance(Binance)
    case huobi(Huobi)
    case whiteBit(WhiteBit)
    case exmo(EXMO)
    
    var apiDescription: String {
        switch self {
        case .binance(let crypto):
            return crypto.rawValue
        case .whiteBit(let crypto):
            return crypto.rawValue
        case .huobi(let crypto):
            return crypto.description
        case .exmo(let exmoCrypto):
            return exmoCrypto.rawValue
        }
    }
    
}
