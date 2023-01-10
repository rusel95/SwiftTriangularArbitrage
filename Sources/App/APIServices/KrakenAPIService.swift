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
    
    struct TickersResponse: Codable {
        let result: [String: Ticker]
    }

    struct Ticker: Codable {
        let a, b, c, v: [String]
        let p: [String]
        let t: [Int]
        let l, h: [String]
        let o: String
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
    
    func getBookTickers() async throws -> [BookTicker] {
        let url: URL = URL(string: "https://api.kraken.com/0/public/Ticker")!
        let (data, _) = try await URLSession.shared.asyncData(from: URLRequest(url: url))
        let response = try JSONDecoder().decode(TickersResponse.self, from: data)
        return response.result.map { key, value in
            return BookTicker(
                symbol: key,
                askPrice: value.a.first ?? "0.0",
                askQty: value.a.last ?? "0.0",
                bidPrice: value.b.first ?? "0.0",
                bidQty: value.b.last ?? "0.0"
            )
        }
    }
   
}
