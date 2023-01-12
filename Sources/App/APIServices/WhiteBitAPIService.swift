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

        enum CodingKeys: String, CodingKey {
            case lastPrice = "last_price"
            case isFrozen
        }
    }

    
    // MARK: - PROPERTIES
    
    static let shared = WhiteBitAPIService()
    
    // MARK: - METHODS
    
    func getSymbols() async throws -> [Market] {
        let url: URL = URL(string: "https://whitebit.com/api/v4/public/markets")!
        let (data, _) = try await URLSession.shared.asyncData(from: URLRequest(url: url))
        return try JSONDecoder().decode([Market].self, from: data)
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
