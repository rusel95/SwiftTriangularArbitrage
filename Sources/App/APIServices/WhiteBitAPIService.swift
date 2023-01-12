//
//  WhiteBitAPIService.swift
//  
//
//  Created by Ruslan on 12.01.2023.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Logging

final class WhiteBitAPIService {
    
    // MARK: - STRUCTS
  
    struct Market: TradeableSymbol {
        var symbol: String { name }
        var baseAsset: String { stock }
        var quoteAsset: String { money }
        
        let name, stock, money: String
        let tradesEnabled: Bool
        let type: TypeEnum
    }

    enum TypeEnum: String, Codable {
        case futures = "futures"
        case spot = "spot"
    }
    
    struct Ticker: Codable {
        let lastPrice: String
        let isFrozen: Bool
        let baseVolume: String
        let quoteVolume: String

        enum CodingKeys: String, CodingKey {
            case lastPrice = "last_price"
            case isFrozen
            case quoteVolume = "quote_volume"
            case baseVolume = "base_volume"
        }
    }

    
    // MARK: - PROPERTIES
    
    static let shared = WhiteBitAPIService()
    
    private let minimumInterestingVolume: Double = 20000
    
    // MARK: - METHODS
    
    func getSymbols() async throws -> [Market] {
        let symbolsUrl: URL = URL(string: "https://whitebit.com/api/v4/public/markets")!
        let (symbolsData, _) = try await URLSession.shared.asyncData(from: URLRequest(url: symbolsUrl))
        let markets = try JSONDecoder().decode([Market].self, from: symbolsData)
        
        let pricesUrl: URL = URL(string: "https://whitebit.com/api/v4/public/ticker")!
        let (pricesData, _) = try await URLSession.shared.asyncData(from: URLRequest(url: pricesUrl))
        let tickersDict = try JSONDecoder().decode([String: Ticker].self, from: pricesData)
        
        return markets
            .filter { $0.type == .spot && $0.tradesEnabled }
            .filter { market in
            let baseSymbol = market.symbol.split(separator: "_").first
            let stableEquivalentBaseSymbolPrice: Double
            if let assetToStableSymbol = tickersDict["\(baseSymbol ?? "")_USDT"] {
                stableEquivalentBaseSymbolPrice = Double(assetToStableSymbol.lastPrice) ?? 0.0
            } else if let stableToAssetSymbol = tickersDict["USDT_\(baseSymbol ?? "")"] {
                stableEquivalentBaseSymbolPrice = Double(stableToAssetSymbol.lastPrice) ?? 0.0
            } else {
                stableEquivalentBaseSymbolPrice = 0.0
            }
            let baseSymbolStableEquivalentVolume = (Double(tickersDict[market.symbol]?.baseVolume ?? "0.0") ?? 0.0) * stableEquivalentBaseSymbolPrice
            return baseSymbolStableEquivalentVolume > minimumInterestingVolume
        }
    }
    
    func getBookTickers() async throws -> [BookTicker] {
        let url: URL = URL(string: "https://whitebit.com/api/v4/public/ticker")!
        let (data, _) = try await URLSession.shared.asyncData(from: URLRequest(url: url))
        let response = try JSONDecoder().decode([String: Ticker].self, from: data)
        return response.compactMap { key, value in
            guard value.isFrozen == false else { return nil }
            
            return BookTicker(
                symbol: key,
                askPrice: value.lastPrice,
                askQty: "0",
                bidPrice: value.lastPrice,
                bidQty: "0"
            )
        }
    }
   
}
