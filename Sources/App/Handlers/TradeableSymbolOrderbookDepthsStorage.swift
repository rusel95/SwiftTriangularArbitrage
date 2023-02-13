//
//  TradeableSymbolOrderbookDepthsStorage.swift
//  
//
//  Created by Ruslan on 09.02.2023.
//

import Foundation

final class TradeableSymbolOrderbookDepthsStorage {
    
    static let shared: TradeableSymbolOrderbookDepthsStorage = TradeableSymbolOrderbookDepthsStorage()
    
    private init() {}
    
    var tradeableSymbolOrderbookDepths: ThreadSafeDictionary<String, TradeableSymbolOrderbookDepth> = ThreadSafeDictionary(dict: [:])
    
}
