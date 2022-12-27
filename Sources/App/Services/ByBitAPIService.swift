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

    struct TickersResponse: Codable {
//        let retCode: Int
//        let retMsg: String
        let result: [Ticker]
//        let extCode, extInfo, timeNow: String

        enum CodingKeys: String, CodingKey {
//            case retCode = "ret_code"
//            case retMsg = "ret_msg"
            case result
//            case extCode = "ext_code"
//            case extInfo = "ext_info"
//            case timeNow = "time_now"
        }
    }

    // MARK: - Result
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


    // MARK: - PROPERTIES
    
    static let shared = ByBitAPIService()
    
    private var logger = Logger(label: "api.whitebit")
    
    // MARK: - METHODS
    
    func getTickersInfo() async throws -> [Ticker] {
        let url: URL = URL(string: "https://api-testnet.bybit.com/v2/public/tickers")!
        let (data, _) = try await URLSession.shared.asyncData(from: URLRequest(url: url))
        let response = try JSONDecoder().decode(TickersResponse.self, from: data)
        return response.result
    }
   
}
