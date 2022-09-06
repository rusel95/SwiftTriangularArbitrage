//
//  BTCTradeAPIService.swift
//  
//
//  Created by Ruslan Popesku on 05.08.2022.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Logging

enum CustomError: Error, CustomStringConvertible {

    // Throw when an expected resource is not found
    case noData
    
    public var description: String {
        switch self {
        case .noData:
            return "The provided password is not valid."
        }
    }
    
}

final class BTCTradeAPIService {
    
    // MARK: - STRUCTS
    
    enum TradeType: String {
        case sell = "bid"
        case buy = "ask"
    }
    
    struct Ticker: Codable {
//        let status: Bool
//        let startPrice, avaragePrice: String
        let endPrice: String
//        let orders: [Order]

        enum CodingKeys: String, CodingKey {
//            case status
//            case startPrice = "start_price"
//            case avaragePrice = "avarage_price"
            case endPrice = "end_price"
//            case orders
        }
    }

    struct Order: Codable {
        let sum, price: String
    }
    
    // MARK: - PROPERTIES
    
    static let shared = BTCTradeAPIService()
    
    private var logger = Logger(label: "api.btc-trade")
    
    // MARK: - METHODS
    
    func loadPriceInfo(
        ticker: String,
        success: @escaping(PricesInfo?) -> Void,
        failure: @escaping(Error) -> Void
    ) {
        var finalError: Error?
        var sellTickerInfo: Ticker?
        var buyTickerInfo: Ticker?
        
        let group = DispatchGroup()
        group.enter()
        
        getPrice(ticker: ticker, tradeType: .sell, success: { tickerInfo in
            sellTickerInfo = tickerInfo
            group.leave()
        }) { error in
            finalError = error
            group.leave()
        }
        
        group.enter()
        getPrice(ticker: ticker, tradeType: .buy, success: { tickerInfo in
            buyTickerInfo = tickerInfo
            group.leave()
        }) { error in
            finalError = error
            group.leave()
        }
        
        group.notify(queue: .global()) {
            if let sellTickerInfo = sellTickerInfo, let possibleSellPrice = Double(sellTickerInfo.endPrice),
               let buyTickerInfo = buyTickerInfo, let possibleBuyPrice = Double(buyTickerInfo.endPrice) {
                success(PricesInfo(possibleSellPrice: possibleSellPrice, possibleBuyPrice: possibleBuyPrice))
            } else if let finalError = finalError {
                failure(finalError)
            } else {
                success(nil)
            }
        }
    }
    
    private func getPrice(
        ticker: String,
        tradeType: TradeType,
        success: @escaping(Ticker) -> Void,
        failure: @escaping(Error) -> Void
    ) {
        let session = URLSession.shared
        let url = URL(string: "https://btc-trade.com.ua/api/\(tradeType.rawValue)/\(ticker)?is_api=1&amount=1000")!
        
        session.dataTask(with: url) { [weak self] (data, response, error) in
            if let error = error {
                self?.logger.warning(Logger.Message(stringLiteral: error.localizedDescription))
                failure(error)
                return
            }
            
            guard let data = data else {
                self?.logger.warning(Logger.Message(stringLiteral: "Empty data for request: \(url.debugDescription)"))
                failure(CustomError.noData)
                return
            }
            
            do {
                let ticker = try JSONDecoder().decode(Ticker.self, from: data)
                success(ticker)
            } catch (let decodingError) {
                self?.logger.error(Logger.Message(stringLiteral: decodingError.localizedDescription))
                failure(decodingError)
            }
        }.resume()
    }
    
}

