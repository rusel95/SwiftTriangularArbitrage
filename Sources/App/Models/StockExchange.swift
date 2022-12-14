//
//  StockExchange.swift
//  
//
//  Created by Ruslan on 30.12.2022.
//

import Foundation

enum StockExchange: String {
    
    case binance, bybit, huobi, exmo, kucoin, kraken, whitebit
    
    var interestingProfit: Double {
        switch self {
        case .binance:
#if DEBUG
            return 0.1
#else
            return 0.3
#endif
        case .bybit:
            return -0.2
        case .huobi:
#if DEBUG
            return 0.1
#else
            return 0.3
#endif
        case .exmo:
            return -0.2
        case .kucoin:
#if DEBUG
            return 0.5
#else
            return 0.6
#endif
        case .kraken:
            return 0.3
        case .whitebit:
            return 0.2
        }
    }
    
    var standartTriangularOpportunityDictKey: String {
        switch self {
        case .binance:
            return "BinanceStandartTriangularOpportunitiesDict"
        case .bybit:
            return "ByBitStandartTriangularOpportunitiesDict"
        case .huobi:
            return "HuobiStandartTriangularOpportunitiesDict"
        case .exmo:
            return "ExmoStandartTriangularOpportunitiesDict"
        case .kucoin:
            return "KuCoinStandartTriangularOpportunitiesDict"
        case .kraken:
            return "KrakenStandartTriangularOpportunitiesDict"
        case .whitebit:
            return "WhiteBitStandartTriangularOpportunitiesDict"
        }
    }
    
    var stableTriangularOpportunityDictKey: String {
        switch self {
        case .binance:
            return "BinanceStableTriangularOpportunitiesDict"
        case .bybit:
            return "ByBitStableTriangularOpportunitiesDict"
        case .huobi:
            return "HuobiStableTriangularOpportunitiesDict"
        case .exmo:
            return "ExmoStableTriangularOpportunitiesDict"
        case .kucoin:
            return "KuCoinStableTriangularOpportunitiesDict"
        case .kraken:
            return "KrakenStableTriangularOpportunitiesDict"
        case .whitebit:
            return "WhiteBitStableTriangularOpportunitiesDict"
        }
    }
    
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
        case .kucoin:
            return URL.documentsDirectory.appendingPathComponent("kucoin_standart_triangulars")
        case .kraken:
            return URL.documentsDirectory.appendingPathComponent("kraken_standart_triangulars")
        case .whitebit:
            return URL.documentsDirectory.appendingPathComponent("whitebit_standart_triangulars")
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
        case .kucoin:
            return URL.documentsDirectory.appendingPathComponent("kucoin_stable_triangulars")
        case .kraken:
            return URL.documentsDirectory.appendingPathComponent("kraken_stable_triangulars")
        case .whitebit:
            return URL.documentsDirectory.appendingPathComponent("whitebit_stable_triangulars")
        }
    }
    
}
