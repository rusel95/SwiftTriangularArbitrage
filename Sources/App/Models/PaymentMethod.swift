//
//  PaymentMethod.swift
//  
//
//  Created by Ruslan Popesku on 30.06.2022.
//

import Foundation
   
enum Crypto: Equatable {
    
    enum Binance: String {
        case usdt = "USDT"
        case busd = "BUSD"
    }
    
    enum Huobi: String {
        case usdt = "usdt"
    }
    
    case binance(Binance)
    case huobi(Huobi)
    
    var apiDescription: String {
        switch self {
        case .binance(let crypto):
            return crypto.rawValue
        case .huobi(let crypto):
            return crypto.rawValue
        }
    }
    
}

enum PaymentMethod: Equatable {
    
    enum Binance: String {
        case privatbank = "Privatbank"
        case monobank = "Monobank"
        case pumb = "PUMBBank"
        case abank = "ABank"
        case wise = "Wise"
        case binancePayUAH = "UAHfiatbalance"

    }
    
    enum Huobi: String {
        case usdtuahSpot = "usdtuah"
    }
    
    case binance(Binance)
    case huobi(Huobi)
    
    var apiDescription: String {
        switch self {
        case .binance(let paymentMethod):
            return paymentMethod.rawValue
        case .huobi(let paymentMethod):
            return paymentMethod.rawValue
        }
    }
    
}
