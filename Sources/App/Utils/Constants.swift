//
//  File.swift
//  
//
//  Created by Ruslan on 30.12.2022.
//

import Foundation

struct Constants {
    
    struct Binance {
        static let tradeableSymbolsDictKey = "binanceTradeableSymbolsDictKey"
        
        static var tradeableDictURL: URL {
            URL.documentsDirectory.appendingPathComponent("binance_tradeable_dict")
        }
    }
    
}
