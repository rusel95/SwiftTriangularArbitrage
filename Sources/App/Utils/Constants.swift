//
//  Constants.swift
//  
//
//  Created by Ruslan on 30.12.2022.
//

import Foundation

struct Constants {
    
    static let minimumQuantityStableEquivalent: Double = 50
    
    static let stablesSet: Set<String> = Set(arrayLiteral: "BUSD", "USDT", "USDC", "TUSD")
    
    static let tradeableAssets: Set<String> = Set(arrayLiteral: "BUSD", "USDT", "USDC", "TUSD", "BTC", "ETH", "BNB", "UAH", "ADA", "DOGE")
    
    struct Binance {
        
        static let tradeableSymbolsDictKey = "binanceTradeableSymbolsDictKey"
        
        static var tradeableDictURL: URL {
            URL.documentsDirectory.appendingPathComponent("binance_tradeable_dict")
        }
    }
    
}
