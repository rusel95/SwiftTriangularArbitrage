//
//  KuCoinAPIService.swift
//  
//
//  Created by Ruslan on 30.12.2022.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Logging

final class KuCoinAPIService {

    // MARK: - PROPERTIES
    
    static let shared = KuCoinAPIService()
    
    // MARK: - SYMBOLS
    
    struct SymbolsResponse: Codable {
        let code: String
        let data: [Symbol]
    }

    struct Symbol: TradeableSymbol {
        var baseAsset: String { baseCurrency }
        var quoteAsset: String { quoteCurrency }
        
        let symbol, name, baseCurrency: String
        let quoteCurrency, feeCurrency: String
        let market: Market
        let baseMinSize, quoteMinSize, baseMaxSize, quoteMaxSize: String
        let baseIncrement, quoteIncrement, priceIncrement, priceLimitRate: String
        let minFunds: String?
        let isMarginEnabled, enableTrading: Bool
    }

    enum Market: String, Codable {
        case alts = "ALTS"
        case btc = "BTC"
        case deFi = "DeFi"
        case etf = "ETF"
        case fiat = "FIAT"
        case kcs = "KCS"
        case nft = "NFT"
        case nftEtf = "NFT-ETF"
        case polkadot = "Polkadot"
        case usds = "USDS"
    }
    
    func getSymbols() async throws -> [Symbol] {
        let url: URL = URL(string: "https://api.kucoin.com/api/v2/symbols")!
        let (data, _) = try await URLSession.shared.asyncData(from: URLRequest(url: url))
        let response = try JSONDecoder().decode(SymbolsResponse.self, from: data)
        return response.data
    }
    
    // MARK: - TICKERS
    
    struct TickersResponse: Codable {
        let code: String
        let data: TickersData
    }

    struct TickersData: Codable {
        let time: UInt
        let ticker: [Ticker]
    }
    
    struct Ticker: Codable {
        let symbol: String
        let buy: String?         // bestAsk
        let sell: String?        // bestBid
    }
    
    func getBookTickers() async throws -> [BookTicker] {
        let url: URL = URL(string: "https://api.kucoin.com/api/v1/market/allTickers")!
        let (data, _) = try await URLSession.shared.asyncData(from: URLRequest(url: url))
        let response = try JSONDecoder().decode(TickersResponse.self, from: data)
        return response.data.ticker.compactMap {
            guard let sell = $0.sell, let buy = $0.buy else { return nil }
            
            return BookTicker(
                symbol: $0.symbol,
                askPrice: sell,
                askQty: "0",
                bidPrice: buy,
                bidQty: "0"
            )
        }
    }
    

    // MARK: - DEPTH
    
    struct OrderBookDepthResponse: Codable {
        let code: String
        let data: OrderBook
    }

    struct OrderBook: Codable {
        let time: Int
        let sequence: String
        let bids: [[String]]
        let asks: [[String]]
    }

    func getOrderbookDepth(symbol: String) async throws -> OrderbookDepth {
        let url: URL = URL(string: "https://api.kucoin.com/api/v1/market/orderbook/level2_20?symbol=\(symbol)")!
        let (data, _) = try await URLSession.shared.asyncData(from: URLRequest(url: url))
        let response = try JSONDecoder().decode(OrderBookDepthResponse.self, from: data)
        return OrderbookDepth(lastUpdateId: 0, asks: response.data.asks, bids: response.data.bids)
    }
    
}
