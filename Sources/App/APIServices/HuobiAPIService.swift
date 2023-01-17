//
//  HuobiAPIService.swift
//  
//
//  Created by Ruslan on 28.12.2022.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Logging

final class HuobiAPIService {

    // MARK: - Symbols
    
    struct SymbolsReponse: Codable {
        let status: String
        let data: [Symbol]
    }

    struct Symbol: TradeableSymbol {
        
        let baseCurrency: String
        let quoteCurrency: String
        let symbol: String
        let state: State

        var baseAsset: String { baseCurrency }
        var quoteAsset: String { quoteCurrency }
        
        enum CodingKeys: String, CodingKey {
            case baseCurrency = "base-currency"
            case quoteCurrency = "quote-currency"
            case symbol, state
        }
    }

    enum State: String, Codable {
        case offline = "offline"
        case online = "online"
    }

    // MARK: - Tickers
    
    struct TickersResponse: Codable {
        let data: [Ticker]
        let status: String
        let ts: Int
    }

    struct Ticker: Codable {
        let symbol: String
        let open, high, low, close: Double
        let amount, vol: Double
        let count: Int
        let bid, bidSize, ask, askSize: Double

        enum CodingKeys: String, CodingKey {
            case symbol, open, high, low, close, amount, vol, count, bid, bidSize, ask, askSize
        }
    }

    // MARK: - PROPERTIES
    
    static let shared = HuobiAPIService()
    
    // MARK: - METHODS
    
    func getSymbolsInfo() async throws -> [Symbol] {
        let url: URL = URL(string: "https://api.huobi.pro/v1/common/symbols")!
        let (data, _) = try await URLSession.shared.asyncData(from: URLRequest(url: url))
        let response = try JSONDecoder().decode(SymbolsReponse.self, from: data)
        return response.data
    }
    
    func getTickers() async throws -> [Ticker] {
        let url: URL = URL(string: "https://api.huobi.pro/market/tickers")!
        let (data, _) = try await URLSession.shared.asyncData(from: URLRequest(url: url))
        let response = try JSONDecoder().decode(TickersResponse.self, from: data)
        return response.data
    }
   
    
    // MARK: - DEPTH
    
    struct DepthResponse: Codable {
        let ch, status: String
        let ts: Int
        let tick: Tick
    }

    struct Tick: Codable {
        let bids, asks: [[Double]]
        let version, ts: Int
    }
    
    func getOrderbookDepth(symbol: String) async throws -> OrderbookDepth {
        let url: URL = URL(string: "https://api.huobi.pro/market/depth?symbol=\(symbol)&type=step1")!
        let (data, _) = try await URLSession.shared.asyncData(from: URLRequest(url: url))
        let response = try JSONDecoder().decode(DepthResponse.self, from: data)
        let asks = response.tick.asks.map { [String($0[0]), String($0[1])] }
        let bids = response.tick.bids.map { [String($0[0]), String($0[1])] }

        return OrderbookDepth(lastUpdateId: 0, asks: asks, bids: bids)
    }
    
    
}
