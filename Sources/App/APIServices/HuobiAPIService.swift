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
   
}
