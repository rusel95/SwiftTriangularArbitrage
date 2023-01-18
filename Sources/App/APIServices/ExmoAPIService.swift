//
//  ExmoAPIService.swift
//  
//
//  Created by Ruslan on 30.12.2022.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class ExmoAPIService {
    
    // MARK: - STRUCTS
    
    struct Symbol: TradeableSymbol {
        let symbol: String
        let baseAsset: String
        let quoteAsset: String
        let info: SymbolInfo
    }

    struct SymbolInfo: Codable {
        let minQuantity, maxQuantity, minPrice, maxPrice: String
        let maxAmount, minAmount: String
        let pricePrecision: Int
        let commissionTakerPercent, commissionMakerPercent: String

        enum CodingKeys: String, CodingKey {
            case minQuantity = "min_quantity"
            case maxQuantity = "max_quantity"
            case minPrice = "min_price"
            case maxPrice = "max_price"
            case maxAmount = "max_amount"
            case minAmount = "min_amount"
            case pricePrecision = "price_precision"
            case commissionTakerPercent = "commission_taker_percent"
            case commissionMakerPercent = "commission_maker_percent"
        }
    }
    
    struct TickerInfo: Codable {
        let buyPrice, sellPrice, lastTrade, high: String
        let low, avg, vol, volCurr: String
        let updated: Int

        enum CodingKeys: String, CodingKey {
            case buyPrice = "buy_price"
            case sellPrice = "sell_price"
            case lastTrade = "last_trade"
            case high, low, avg, vol
            case volCurr = "vol_curr"
            case updated
        }
    }


    // MARK: - PROPERTIES
    
    static let shared = ExmoAPIService()
    
    // MARK: - METHODS
    
    func getSymbols() async throws -> [Symbol] {
        let url: URL = URL(string: "https://api.exmo.com/v1.1/pair_settings")!
        let (data, _) = try await URLSession.shared.asyncData(from: URLRequest(url: url))
        let response = try JSONDecoder().decode([String: SymbolInfo].self, from: data)
        return response.map {
            let symbolElements = $0.key.components(separatedBy: "_")
            return Symbol(
                symbol: $0.key,
                baseAsset: symbolElements.first ?? "",
                quoteAsset: symbolElements.last ?? "",
                info: $0.value
            )
        }
    }
    
    func getBookTickers() async throws -> [BookTicker] {
        let url: URL = URL(string: "https://api.exmo.com/v1.1/ticker")!
        let (data, _) = try await URLSession.shared.asyncData(from: URLRequest(url: url))
        let response = try JSONDecoder().decode([String: TickerInfo].self, from: data)
        return response.map {
            BookTicker(
                symbol: $0.key,
                askPrice: $0.value.sellPrice,
                askQty: "0",
                bidPrice: $0.value.buyPrice,
                bidQty: "0"
            )
        }
    }
    

   
}
