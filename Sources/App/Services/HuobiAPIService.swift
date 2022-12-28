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
        let data: [SymbolInfo]
    }

    struct SymbolInfo: Codable {
        let baseCurrency: String
        let quoteCurrency: String
        let pricePrecision, amountPrecision: Int
//        let symbolPartition: SymbolPartition
        let symbol: String
        let state: State
        let valuePrecision: Int
        let minOrderAmt, maxOrderAmt, minOrderValue, limitOrderMinOrderAmt: Double
        let limitOrderMaxOrderAmt, limitOrderMaxBuyAmt, limitOrderMaxSellAmt, buyLimitMustLessThan: Double
        let sellLimitMustGreaterThan, sellMarketMinOrderAmt, sellMarketMaxOrderAmt, buyMarketMaxOrderValue: Double
        let marketSellOrderRateMustLessThan, marketBuyOrderRateMustLessThan: Double
        let leverageRatio: Double?
        let superMarginLeverageRatio, fundingLeverageRatio: Int?
        let apiTrading: APITrading
        let tags: Tags?
        let maxOrderValue: Int?
        let underlying: String?
        let mgmtFeeRate: Double?
        let chargeTime, rebalTime: String?
        let rebalThreshold: Int?
        let initNav: Double?

        enum CodingKeys: String, CodingKey {
            case baseCurrency = "base-currency"
            case quoteCurrency = "quote-currency"
            case pricePrecision = "price-precision"
            case amountPrecision = "amount-precision"
//            case symbolPartition = "symbol-partition"
            case symbol, state
            case valuePrecision = "value-precision"
            case minOrderAmt = "min-order-amt"
            case maxOrderAmt = "max-order-amt"
            case minOrderValue = "min-order-value"
            case limitOrderMinOrderAmt = "limit-order-min-order-amt"
            case limitOrderMaxOrderAmt = "limit-order-max-order-amt"
            case limitOrderMaxBuyAmt = "limit-order-max-buy-amt"
            case limitOrderMaxSellAmt = "limit-order-max-sell-amt"
            case buyLimitMustLessThan = "buy-limit-must-less-than"
            case sellLimitMustGreaterThan = "sell-limit-must-greater-than"
            case sellMarketMinOrderAmt = "sell-market-min-order-amt"
            case sellMarketMaxOrderAmt = "sell-market-max-order-amt"
            case buyMarketMaxOrderValue = "buy-market-max-order-value"
            case marketSellOrderRateMustLessThan = "market-sell-order-rate-must-less-than"
            case marketBuyOrderRateMustLessThan = "market-buy-order-rate-must-less-than"
            case leverageRatio = "leverage-ratio"
            case superMarginLeverageRatio = "super-margin-leverage-ratio"
            case fundingLeverageRatio = "funding-leverage-ratio"
            case apiTrading = "api-trading"
            case tags
            case maxOrderValue = "max-order-value"
            case underlying
            case mgmtFeeRate = "mgmt-fee-rate"
            case chargeTime = "charge-time"
            case rebalTime = "rebal-time"
            case rebalThreshold = "rebal-threshold"
            case initNav = "init-nav"
        }
    }

    enum APITrading: String, Codable {
        case disabled = "disabled"
        case enabled = "enabled"
    }

    enum State: String, Codable {
        case offline = "offline"
        case online = "online"
    }

    enum SymbolPartition: String, Codable {
        case main = "main"
        case st = "st"
    }

    enum Tags: String, Codable {
        case abnormalmarket = "abnormalmarket"
        case abnormalmarketHadax = "abnormalmarket,hadax"
        case abnormalmarketHadaxHighrisk = "abnormalmarket,hadax,highrisk"
        case activities = "activities"
        case altsAbnormalmarket = "alts,abnormalmarket"
        case crypto = "crypto"
        case empty = ""
        case etpNavHoldinglimit = "etp,nav,holdinglimit"
        case etpNavHoldinglimitActivities = "etp,nav,holdinglimit,activities"
        case fiat = "fiat"
        case griddisabled = "griddisabled"
        case griddisabledFiat = "griddisabled,fiat"
        case griddisabledSt = "griddisabled,st"
        case griddisabledStAbnormalmarket = "griddisabled,st,abnormalmarket"
        case griddisabledStHadax = "griddisabled,st,hadax"
        case hadax = "hadax"
        case hadaxAbnormalmarket = "hadax,abnormalmarket"
        case hadaxHad = "hadax,had"
        case hadaxHighrisk = "hadax,highrisk"
        case st = "st"
        case stAbnormalmarket = "st,abnormalmarket"
        case stHadax = "st,hadax"
        case stHadaxAbnormalmarket = "st,hadax,abnormalmarket"
        case stHighrisk = "st,highrisk"
        case zerofee = "zerofee"
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
    
    private var logger = Logger(label: "api.huobi")
    
    // MARK: - METHODS
    
    func getSymbolsInfo() async throws -> [SymbolInfo] {
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
   
}
