//
//  StockExchange.swift
//  
//
//  Created by Ruslan on 30.12.2022.
//

import Foundation

enum StockExchange: String {
    
    case binance, bybit, huobi, exmo
    
    var standartTriangularsStorageURL: URL {
        switch self {
        case .binance:
            return URL.documentsDirectory.appendingPathComponent("binance_standart_triangulars")
        case .bybit:
            return URL.documentsDirectory.appendingPathComponent("bybit_standart_triangulars")
        case .huobi:
            return URL.documentsDirectory.appendingPathComponent("huobi_standart_triangulars")
        case .exmo:
            return URL.documentsDirectory.appendingPathComponent("exmo_standart_triangulars")
        }
    }
    
    var stableTriangularsStorageURL: URL {
        switch self {
        case .binance:
            return URL.documentsDirectory.appendingPathComponent("binance_stable_triangulars")
        case .bybit:
            return URL.documentsDirectory.appendingPathComponent("bybit_stable_triangulars")
        case .huobi:
            return URL.documentsDirectory.appendingPathComponent("huobi_stable_triangulars")
        case .exmo:
            return URL.documentsDirectory.appendingPathComponent("exmo_stable_triangulars")
        }
    }
    
}
