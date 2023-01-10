//
//  ByBitAPIService.swift
//  
//
//  Created by Ruslan on 27.12.2022.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Logging

final class ByBitAPIService {
    
    // MARK: - STRUCTS

    struct TickerResponse: Codable {
        let result: [Ticker]
    }
    
    struct SymbolResponse: Codable {
        let result: [Symbol]
    }


    // MARK: - Ticker
    
    struct Ticker: Codable {
        let symbol, bidPrice, askPrice: String

        enum CodingKeys: String, CodingKey {
            case symbol
            case bidPrice = "bid_price"
            case askPrice = "ask_price"
        }
    }

    // MARK: - Result
    struct Symbol: TradeableSymbol {
        
        let name, alias, status, baseCurrency, quoteCurrency: String
        
        var symbol: String { name }
        var baseAsset: String { baseCurrency }
        var quoteAsset: String { quoteCurrency }

        enum CodingKeys: String, CodingKey {
            case name, alias, status
            case baseCurrency = "base_currency"
            case quoteCurrency = "quote_currency"
        }
    }

    // MARK: - LeverageFilter
    struct LeverageFilter: Codable {
        let minLeverage, maxLeverage: Int
        let leverageStep: String

        enum CodingKeys: String, CodingKey {
            case minLeverage = "min_leverage"
            case maxLeverage = "max_leverage"
            case leverageStep = "leverage_step"
        }
    }

    // MARK: - LotSizeFilter
    struct LotSizeFilter: Codable {
        let maxTradingQty: Int
        let minTradingQty, qtyStep: Double
        let postOnlyMaxTradingQty: String

        enum CodingKeys: String, CodingKey {
            case maxTradingQty = "max_trading_qty"
            case minTradingQty = "min_trading_qty"
            case qtyStep = "qty_step"
            case postOnlyMaxTradingQty = "post_only_max_trading_qty"
        }
    }

    // MARK: - PriceFilter
    struct PriceFilter: Codable {
        let minPrice, maxPrice, tickSize: String

        enum CodingKeys: String, CodingKey {
            case minPrice = "min_price"
            case maxPrice = "max_price"
            case tickSize = "tick_size"
        }
    }


    // MARK: - PROPERTIES
    
    static let shared = ByBitAPIService()
    
    private var logger = Logger(label: "api.bybit")
    
    // MARK: - METHODS
    
    func getSymbols() async throws -> [Symbol] {
        let url: URL = URL(string: "https://api-testnet.bybit.com/v2/public/symbols")!
        let (data, _) = try await URLSession.shared.asyncData(from: URLRequest(url: url))
        let response = try JSONDecoder().decode(SymbolResponse.self, from: data)
        return response.result
    }
    
    func getTickers() async throws -> [Ticker] {
        let url: URL = URL(string: "https://api-testnet.bybit.com/v2/public/tickers")!
        let (data, _) = try await URLSession.shared.asyncData(from: URLRequest(url: url))
        let response = try JSONDecoder().decode(TickerResponse.self, from: data)
        return response.result
    }
   
}
