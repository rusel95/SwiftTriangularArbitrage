//
//  TradeableSymbol.swift
//  
//
//  Created by Ruslan on 27.12.2022.
//

import Foundation

protocol TradeableSymbol: Codable {
    
    var symbol: String { get }
    var baseAsset: String { get }
    var quoteAsset: String { get }
    
}
