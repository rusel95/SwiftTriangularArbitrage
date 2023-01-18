//
//  GateIOAPIService.swift
//  
//
//  Created by Ruslan on 17.01.2023.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import AsyncHTTPClient

final class GateIOAPIService {

    // MARK: - PROPERTIES
    
    static let shared = GateIOAPIService()
    
    let httpClient = HTTPClient(eventLoopGroupProvider: .createNew)
    
    // MARK: - SYMBOLS
    
    struct Symbol: TradeableSymbol {
        
        var symbol: String { id }
        
        var baseAsset: String { base }
        
        var quoteAsset: String { quote }
        
        let id, base, quote: String
        let fee: String
        let minQuoteAmount: String?
        let amountPrecision, precision: Int
        let tradeStatus: TradeStatus
        let sellStart, buyStart: Int
        let minBaseAmount: String?

        enum CodingKeys: String, CodingKey {
            case id, base, quote, fee
            case minQuoteAmount = "min_quote_amount"
            case amountPrecision = "amount_precision"
            case precision
            case tradeStatus = "trade_status"
            case sellStart = "sell_start"
            case buyStart = "buy_start"
            case minBaseAmount = "min_base_amount"
        }
    }

    enum TradeStatus: String, Codable {
        case sellable = "sellable"
        case tradable = "tradable"
        case untradable = "untradable"
    }
    
    func getSymbols() async throws -> [Symbol] {
        let request = try HTTPClient.Request(url: "https://api.gateio.ws/api/v4/spot/currency_pairs")
        let response = try await httpClient.execute(request: request).get()
        return try JSONDecoder().decode([Symbol].self, from: response.body!)
    }
    
    // MARK: - TICKERS
    
    struct Ticker: Codable {
        let currencyPair, lowestAsk, highestBid: String?

        enum CodingKeys: String, CodingKey {
            case currencyPair = "currency_pair"
            case lowestAsk = "lowest_ask"
            case highestBid = "highest_bid"
        }
    }
    func getBookTickers() async throws -> [BookTicker] {
        let request = try HTTPClient.Request(url: "https://api.gateio.ws/api/v4/spot/tickers")
        let response = try await httpClient.execute(request: request).get()
        let tickers = try JSONDecoder().decode([Ticker].self, from: response.body!)
        return tickers.compactMap {
            guard let currencyPair = $0.currencyPair, let lowestAsk = $0.lowestAsk, let highestBid = $0.highestBid else { return nil }
            
            return BookTicker(
                symbol: currencyPair,
                askPrice: lowestAsk,
                askQty: "0",
                bidPrice: highestBid,
                bidQty: "0"
            )
        }
    }

    // MARK: - DEPTH
    
    struct OrderBook: Codable {
        let current, update: Int
        let asks: [[String]]
        let bids: [[String]]
    }
    
    func getOrderbookDepth(symbol: String, limit: UInt) async throws -> OrderbookDepth {
        let request = try HTTPClient.Request(url: "https://api.gateio.ws/api/v4/spot/order_book?currency_pair=\(symbol)&limit=\(limit)")
        let response = try await httpClient.execute(request: request).get()
        let orderBook = try JSONDecoder().decode(OrderBook.self, from: response.body!)
        return OrderbookDepth(lastUpdateId: 0, asks: orderBook.asks, bids: orderBook.bids)
    }
    
}
