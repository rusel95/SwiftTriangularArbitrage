//
//  Crypto.swift
//  
//
//  Created by Ruslan Popesku on 30.06.2022.
//

enum Currency: String, Equatable {
    
    case uah = "UAH"
    case usd = "USD"
    case eur = "EUR"
    case usdt = "USDT"
    case busd = "BUSD"
    case btc = "BTC"
    case bnb = "BNB"
    
    var apiDescription: String {
        return rawValue
    }
    
}
