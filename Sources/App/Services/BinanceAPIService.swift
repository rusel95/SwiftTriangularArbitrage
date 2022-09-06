//
//  BinanceAPIService.swift
//  
//
//  Created by Ruslan Popesku on 23.06.2022.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Logging

final class BinanceAPIService {
    
    // MARK: - STRUCTS
    
    enum TradeType: String {
        case sell = "SELL"
        case buy = "BUY"
    }
    
    struct Welcome: Codable {
        
        let data: [Datum]
        
    }
    
    struct Datum: Codable {
        
        let adv: Adv
        
    }
    
    struct Adv: Codable {
    
        let price, surplusAmount: String
        let maxSingleTransAmount, minSingleTransAmount: String
        
    }
    
    struct BookTicker: Codable {
        
        let symbol: String
        let bidPrice: String
//        let bidQty: String
        let askPrice: String
//        let askQty: String
        
        var sellPrice: Double? {
            Double(bidPrice)
        }
        
        var buyPrice: Double? {
            Double(askPrice)
        }
        
    }
    
    // MARK: - Welcome
    struct ExchangeInfoResponse: Codable {
//        let timezone: String
//        let serverTime: Int
//        let rateLimits: [RateLimit]
//        let exchangeFilters: [JSONAny]
        let symbols: [Symbol]
    }

    // MARK: - RateLimit
    struct RateLimit: Codable {
        let rateLimitType, interval: String
        let intervalNum, limit: Int
    }

    // MARK: - Symbol
    struct Symbol: Codable {
        let symbol: String
        let status: Status
        let baseAsset: String
//        let baseAssetPrecision: Int
        let quoteAsset: String
//        let quotePrecision, quoteAssetPrecision, baseCommissionPrecision, quoteCommissionPrecision: Int
//        let orderTypes: [OrderType]
//        let icebergAllowed, ocoAllowed, quoteOrderQtyMarketAllowed, allowTrailingStop: Bool
//        let cancelReplaceAllowed, isSpotTradingAllowed, isMarginTradingAllowed: Bool
//        let filters: [Filter]
//        let permissions: [Permission]
    }

    // MARK: - Filter
//    struct Filter: Codable {
//        let filterType: FilterType
//        let minPrice, maxPrice, tickSize, multiplierUp: String?
//        let multiplierDown: String?
//        let avgPriceMins: Int?
//        let minQty, maxQty, stepSize, minNotional: String?
//        let applyToMarket: Bool?
//        let limit, minTrailingAboveDelta, maxTrailingAboveDelta, minTrailingBelowDelta: Int?
//        let maxTrailingBelowDelta, maxNumOrders, maxNumAlgoOrders: Int?
//        let bidMultiplierUp, bidMultiplierDown, askMultiplierUp, askMultiplierDown: String?
//        let maxPosition: String?
//    }
//
//    enum FilterType: String, Codable {
//        case icebergParts = "ICEBERG_PARTS"
//        case lotSize = "LOT_SIZE"
//        case marketLotSize = "MARKET_LOT_SIZE"
//        case maxNumAlgoOrders = "MAX_NUM_ALGO_ORDERS"
//        case maxNumOrders = "MAX_NUM_ORDERS"
//        case maxPosition = "MAX_POSITION"
//        case minNotional = "MIN_NOTIONAL"
//        case percentPrice = "PERCENT_PRICE"
//        case percentPriceBySide = "PERCENT_PRICE_BY_SIDE"
//        case priceFilter = "PRICE_FILTER"
//        case trailingDelta = "TRAILING_DELTA"
//    }

//    enum OrderType: String, Codable {
//        case limit = "LIMIT"
//        case limitMaker = "LIMIT_MAKER"
//        case market = "MARKET"
//        case stopLossLimit = "STOP_LOSS_LIMIT"
//        case takeProfitLimit = "TAKE_PROFIT_LIMIT"
//    }
//
//    enum Permission: String, Codable {
//        case leveraged = "LEVERAGED"
//        case margin = "MARGIN"
//        case spot = "SPOT"
//        case trdGrp003 = "TRD_GRP_003"
//        case trdGrp004 = "TRD_GRP_004"
//    }

    enum Status: String, Codable {
        case statusBREAK = "BREAK"
        case trading = "TRADING"
    }
    
    // MARK: - PROPERTIES
    
    static let shared = BinanceAPIService()
    
    private var logger = Logger(label: "api.binance")
    
    // MARK: - METHODS
    
    func getBookTicker(
        symbol: String,
        completion: @escaping(_ ticker: BookTicker?) -> Void
    ) {
        let session = URLSession.shared
        let url = URL(string: "https://api.binance.com/api/v3/ticker/bookTicker?symbol=\(symbol)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "Get"
        
        session.dataTask(with: request) { [weak self] (data, response, error) in
            if let error = error {
                self?.logger.warning(Logger.Message(stringLiteral: error.localizedDescription))
                completion(nil)
                return
            }
            
            guard let data = data else {
                self?.logger.warning(Logger.Message(stringLiteral: "NO DATA for Binance Spot \(url.debugDescription)"))
                completion(nil)
                return
            }
            
            do {
                let ticker = try JSONDecoder().decode(BookTicker.self, from: data)
                completion(ticker)
            } catch (let decodingError) {
                self?.logger.error(Logger.Message(stringLiteral: decodingError.localizedDescription))
                completion(nil)
            }
        }.resume()
    }
    
    func getAllBookTickers(completion: @escaping(_ tickers: [BookTicker]?) -> Void) {
        let session = URLSession.shared
        let url = URL(string: "https://api.binance.com/api/v3/ticker/bookTicker")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "Get"
        
        session.dataTask(with: request) { [weak self] (data, response, error) in
            if let error = error {
                self?.logger.warning(Logger.Message(stringLiteral: error.localizedDescription))
                completion(nil)
                return
            }
            
            guard let data = data else {
                self?.logger.warning(Logger.Message(stringLiteral: "NO DATA for Binance Tickers \(url.debugDescription)"))
                completion(nil)
                return
            }
            
            do {
                let ticker = try JSONDecoder().decode([BookTicker].self, from: data)
                completion(ticker)
            } catch (let decodingError) {
                self?.logger.error(Logger.Message(stringLiteral: decodingError.localizedDescription))
                completion(nil)
            }
        }.resume()
    }
    
    func getExchangeInfo(completion: @escaping(_ symbols: [Symbol]?) -> Void) {
        let session = URLSession.shared
        let url = URL(string: "https://api.binance.com/api/v3/exchangeInfo")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "Get"
        
        session.dataTask(with: request) { [weak self] (data, response, error) in
            if let error = error {
                self?.logger.warning(Logger.Message(stringLiteral: error.localizedDescription))
                completion(nil)
                return
            }
            
            guard let data = data else {
                self?.logger.warning(Logger.Message(stringLiteral: "NO DATA for Binance Symbols \(url.debugDescription)"))
                completion(nil)
                return
            }
            
            do {
                let response = try JSONDecoder().decode(ExchangeInfoResponse.self, from: data)
                completion(response.symbols)
            } catch (let decodingError) {
                self?.logger.error(Logger.Message(stringLiteral: decodingError.localizedDescription))
                completion(nil)
            }
        }.resume()
    }
    
    func loadAdvertisements(
        paymentMethod: String,
        crypto: String,
        numberOfAdvsToConsider: UInt8 = 10,
        completion: @escaping(_ buyAdvs: [Adv]?, _ sellAdvs: [Adv]?, _ error: Error?) -> Void
    ) {
        var finalError: Error?
        var buyAdvs: [Adv]?
        var sellAdvs: [Adv]?
        
        let group = DispatchGroup()
        group.enter()
        
        loadAdvertisements(paymentMethod: paymentMethod,
                           crypto: crypto,
                           numberOfAdvsToConsider: numberOfAdvsToConsider,
                           tradeType: .sell) { advs, error in
            sellAdvs = advs
            if let error = error {
                finalError = error
            }
            group.leave()
        }
        
        group.enter()
        loadAdvertisements(paymentMethod: paymentMethod,
                           crypto: crypto,
                           numberOfAdvsToConsider: numberOfAdvsToConsider,
                           tradeType: .buy) { advs, error in
            buyAdvs = advs
            if let error = error {
                finalError = error
            }
            group.leave()
        }
        
        group.notify(queue: .global()) {
            completion(buyAdvs, sellAdvs, finalError)
        }
    }
    
    func loadAdvertisements(
        paymentMethod: String,
        crypto: String,
        numberOfAdvsToConsider: UInt8 = 10,
        tradeType: TradeType,
        completion: @escaping(_ advs: [Adv]?, _ error: Error?) -> Void
    ) {
        let session = URLSession.shared
        let url = URL(string: "https://p2p.binance.com/bapi/c2c/v2/friendly/c2c/adv/search")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("p2p.binance.com", forHTTPHeaderField: "Host")
        request.setValue("https://p2p.binance.com", forHTTPHeaderField: "Origin")
        request.setValue("Trailers", forHTTPHeaderField: "TE")
        
        let parametersDictionary: [String : Any] = [
            "asset": crypto,
            "fiat": "UAH",
            "page": 1,
            "payTypes": [paymentMethod],
            "rows": numberOfAdvsToConsider,
            "tradeType": tradeType.rawValue
        ]
//            "transAmount": "2000.00",
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: parametersDictionary) as Data
        session.dataTask(with: request) { [weak self] (data, response, error) in
            if let error = error {
                self?.logger.warning(Logger.Message(stringLiteral: error.localizedDescription))
                completion(nil, error)
                return
            }
            
            guard let data = data else {
                self?.logger.warning(Logger.Message(stringLiteral: "Empty data for request: \(request.debugDescription)"))
                completion(nil, nil)
                return
            }
            
            do {
                let welcome = try JSONDecoder().decode(Welcome.self, from: data)
                let advs = welcome.data.compactMap { $0.adv }
                completion(advs, nil)
            } catch (let decodingError) {
                self?.logger.error(Logger.Message(stringLiteral: decodingError.localizedDescription))
                completion(nil, error)
            }
        }.resume()
    }
    
}

