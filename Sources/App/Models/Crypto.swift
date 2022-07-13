//
//  Crypto.swift
//  
//
//  Created by Ruslan Popesku on 30.06.2022.
//

enum Crypto: String, Equatable {
    
    case usdt = "USDT"
    case busd = "BUSD"
    case btc = "BTC"
    case bnb = "BNB"
    
    var apiDescription: String {
        return rawValue
    }
    
}
