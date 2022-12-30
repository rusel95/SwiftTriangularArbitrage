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
        let symbol, bidPrice, askPrice, lastPrice: String
//        let lastTickDirection, prevPrice24H, price24HPcnt, highPrice24H: String
//        let lowPrice24H, prevPrice1H, markPrice, indexPrice: String
//        let openInterest, countdownHour: Int
//        let turnover24H: String
//        let volume24H: Int
//        let fundingRate, predictedFundingRate: String
//        let nextFundingTime: Date
//        let predictedDeliveryPrice, totalTurnover: String
//        let totalVolume: Int
//        let deliveryFeeRate, deliveryTime, price1HPcnt, openValue: String

        enum CodingKeys: String, CodingKey {
            case symbol
            case bidPrice = "bid_price"
            case askPrice = "ask_price"
            case lastPrice = "last_price"
//            case lastTickDirection = "last_tick_direction"
//            case prevPrice24H = "prev_price_24h"
//            case price24HPcnt = "price_24h_pcnt"
//            case highPrice24H = "high_price_24h"
//            case lowPrice24H = "low_price_24h"
//            case prevPrice1H = "prev_price_1h"
//            case markPrice = "mark_price"
//            case indexPrice = "index_price"
//            case openInterest = "open_interest"
//            case countdownHour = "countdown_hour"
//            case turnover24H = "turnover_24h"
//            case volume24H = "volume_24h"
//            case fundingRate = "funding_rate"
//            case predictedFundingRate = "predicted_funding_rate"
//            case nextFundingTime = "next_funding_time"
//            case predictedDeliveryPrice = "predicted_delivery_price"
//            case totalTurnover = "total_turnover"
//            case totalVolume = "total_volume"
//            case deliveryFeeRate = "delivery_fee_rate"
//            case deliveryTime = "delivery_time"
//            case price1HPcnt = "price_1h_pcnt"
//            case openValue = "open_value"
        }
    }

    // MARK: - Result
    struct Symbol: TradeableSymbol {
        
        let name, alias, status, baseCurrency: String
        let quoteCurrency: String
        let priceScale: Int
        let takerFee, makerFee: String
        let fundingInterval: Int
        let leverageFilter: LeverageFilter
        let priceFilter: PriceFilter
        let lotSizeFilter: LotSizeFilter
        
        var symbol: String { name }
        var baseAsset: String { baseCurrency }
        var quoteAsset: String { quoteCurrency }

        enum CodingKeys: String, CodingKey {
            case name, alias, status
            case baseCurrency = "base_currency"
            case quoteCurrency = "quote_currency"
            case priceScale = "price_scale"
            case takerFee = "taker_fee"
            case makerFee = "maker_fee"
            case fundingInterval = "funding_interval"
            case leverageFilter = "leverage_filter"
            case priceFilter = "price_filter"
            case lotSizeFilter = "lot_size_filter"
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
    
    func getTickers() async throws -> [Ticker] {
        let url: URL = URL(string: "https://api-testnet.bybit.com/v2/public/tickers")!
        let (data, _) = try await URLSession.shared.asyncData(from: URLRequest(url: url))
        let response = try JSONDecoder().decode(TickerResponse.self, from: data)
        return response.result
    }
    
    func getSymbols() async throws -> [Symbol] {
        let url: URL = URL(string: "https://api-testnet.bybit.com/v2/public/symbols")!
        let (data, _) = try await URLSession.shared.asyncData(from: URLRequest(url: url))
        let response = try JSONDecoder().decode(SymbolResponse.self, from: data)
        return response.result
    }
   
}
