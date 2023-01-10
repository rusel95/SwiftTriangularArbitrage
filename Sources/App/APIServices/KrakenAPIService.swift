//
//  KrakenAPIService.swift
//  
//
//  Created by Ruslan on 10.01.2023.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Logging

final class KrakenAPIService {
    
    // MARK: - STRUCTS
    
    struct AssetPairsResponse: Decodable {
        let result: [String: AssetPair]
    }
    
    struct AssetPair: TradeableSymbol {
        
        var symbol: String { altname }
        
        var baseAsset: String { base }
        
        var quoteAsset: String { quote }
        
        let altname, wsname: String
        let base, quote: String
        let status: Status
        
        enum CodingKeys: String, CodingKey {
            case altname, wsname
            case base
            case quote
            case status
        }
        
    }

    enum Status: String, Codable {
        case cancelOnly = "cancel_only"
        case online = "online"
        case reduceOnly = "reduce_only"
    }

    // MARK: - PROPERTIES
    
    static let shared = KrakenAPIService()
    
    // MARK: - METHODS
    
    func getSymbols() async throws -> [AssetPair] {
        let url: URL = URL(string: "https://api.kraken.com/0/public/AssetPairs")!
        let (data, _) = try await URLSession.shared.asyncData(from: URLRequest(url: url))
        let response = try JSONDecoder().decode(AssetPairsResponse.self, from: data)
        return response.result.map { $0.value }
    }
    
//    func getBookTickers() async throws -> [BookTicker] {
//        let url: URL = URL(string: "https://api.kucoin.com/api/v1/market/allTickers")!
//        let (data, _) = try await URLSession.shared.asyncData(from: URLRequest(url: url))
//        let response = try JSONDecoder().decode(TickersResponse.self, from: data)
//        return response.data.ticker.map {
//            BookTicker(
//                symbol: $0.symbol,
//                askPrice: $0.sell,
//                askQty: "0",
//                bidPrice: $0.buy,
//                bidQty: "0"
//            )
//        }
//    }
   
}
