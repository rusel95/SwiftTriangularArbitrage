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
import Crypto

enum OrderSide: String {
    case quoteToBase = "BUY"
    case baseToQuote = "SELL"
    case unknown = "UNKNOWN"
}

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
        let baseAssetPrecision: Int
        let quoteAsset: String
        let quotePrecision, quoteAssetPrecision, baseCommissionPrecision, quoteCommissionPrecision: Int
        //        let orderTypes: [OrderType]
        //        let icebergAllowed, ocoAllowed, quoteOrderQtyMarketAllowed, allowTrailingStop: Bool
        //        let cancelReplaceAllowed: String
        let isSpotTradingAllowed: Bool
        //        let isMarginTradingAllowed: Bool
        let filters: [Filter]
        //        let permissions: [Permission]
    }
    
    // MARK: - Filter
    struct Filter: Codable {
        let filterType: FilterType
        let minPrice, maxPrice, tickSize, multiplierUp: String?
        let multiplierDown: String?
        let avgPriceMins: Int?
        let minQty, maxQty, stepSize, minNotional: String?
        let applyToMarket: Bool?
        let limit, minTrailingAboveDelta, maxTrailingAboveDelta, minTrailingBelowDelta: Int?
        let maxTrailingBelowDelta, maxNumOrders, maxNumAlgoOrders: Int?
        let bidMultiplierUp, bidMultiplierDown, askMultiplierUp, askMultiplierDown: String?
        let maxPosition: String?
    }
    
    enum FilterType: String, Codable {
        case icebergParts = "ICEBERG_PARTS"
        case lotSize = "LOT_SIZE"
        case marketLotSize = "MARKET_LOT_SIZE"
        case maxNumAlgoOrders = "MAX_NUM_ALGO_ORDERS"
        case maxNumOrders = "MAX_NUM_ORDERS"
        case maxPosition = "MAX_POSITION"
        case minNotional = "MIN_NOTIONAL"
        case percentPrice = "PERCENT_PRICE"
        case percentPriceBySide = "PERCENT_PRICE_BY_SIDE"
        case priceFilter = "PRICE_FILTER"
        case trailingDelta = "TRAILING_DELTA"
    }
    
    enum Permission: String, Codable {
        case leveraged = "LEVERAGED"
        case margin = "MARGIN"
        case spot = "SPOT"
        case trdGrp003 = "TRD_GRP_003"
        case trdGrp004 = "TRD_GRP_004"
    }
    
    enum Status: String, Codable {
        case statusBREAK = "BREAK"
        case trading = "TRADING"
    }
    
    // MARK: - PROPERTIES
    
    static let shared = BinanceAPIService()
    
    private var logger = Logger(label: "api.binance")
    
    private lazy var apiKeyString: String = {
        String.readToken(from: "binanceAPIKey")
    }()
    
    private lazy var secretString: String = {
        String.readToken(from: "binanceSecretKey")
    }()
    
    // MARK: - METHODS
    
    func getBookTickers(
        symbols: [String],
        completion: @escaping(_ tickers: [BookTicker]?) -> Void
    ) {
        let symbolsListDescription = symbols.map { String($0) }.joined(separator: ",")
        let url: URL = URL(string: "https://api.binance.com/api/v3/ticker/bookTicker?symbols=[\(symbolsListDescription)]")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "Get"
        
        URLSession.shared.dataTask(with: request) { [weak self] (data, response, error) in
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
                let tickers = try JSONDecoder().decode([BookTicker].self, from: data)
                completion(tickers)
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
    
    // MARK: - Depth
    
    func getOrderbookDepth(symbol: String, limit: UInt) async throws -> OrderbookDepth {
        let url: URL = URL(string: "https://api.binance.com/api/v3/depth?limit=\(limit)&symbol=\(symbol)")!
        let (data, _) = try await URLSession.shared.asyncData(from: URLRequest(url: url))
        return try JSONDecoder().decode(OrderbookDepth.self, from: data)
    }
    
    // MARK: - NewOrder
    
    enum OrderType: String {
        case limit = "LIMIT"
        case market = "MARKET"
        case stopLoss = "STOP_LOSS"
        case stopLossLimit = "STOP_LOSS_LIMIT"
        case takeProfit = "TAKE_PROFIT"
        case takeProfitLimit = "TAKE_PROFIT_LIMIT"
        case limitMaker = "LIMIT_MAKER"
    }
    
    enum OrderStatus: String {
        case new = "NEW"                            // The order has been accepted by the engine.
        case partiallyFilled = "PARTIALLY_FILLED"   // A part of the order has been filled.
        case filled = "FILLED"                      // The order has been completed.
        case canceled = "CANCELED"                  // The order has been canceled by the user.
        case pendingCancel = "PENDING_CANCEL"       // Currently unused
        case rejected = "REJECTED"                  // The order was not accepted by the engine and not processed.
        case expired = "EXPIRED"                    // The order was canceled according to the order type's rules (e.g. LIMIT FOK orders with no fill, LIMIT IOC or MARKET orders that partially fill) or by the exchange, (e.g. orders canceled during liquidation, orders canceled during maintenance)
    }
    
    enum OrderResponseType: String {
        case ack = "ACK"
        case result = "RESULT"
        case full = "FULL"
    }
    
    struct NewOrderResponse: Codable {
        
        let symbol: String
        let orderID, orderListID: Int
        let clientOrderID: String
        let transactTime: Int
        let price, origQty, executedQty, cummulativeQuoteQty: String
        let status, timeInForce, type, side: String
        let fills: [Fill]
        
        enum CodingKeys: String, CodingKey {
            case symbol
            case orderID = "orderId"
            case orderListID = "orderListId"
            case clientOrderID = "clientOrderId"
            case transactTime, price, origQty, executedQty, cummulativeQuoteQty, status, timeInForce, type, side, fills
        }
        
        var averageExecutedPrice: Double {
            (Double(cummulativeQuoteQty) ?? 0.0) / (Double(executedQty) ?? 1.0)
        }
        
    }
    
    struct Fill: Codable, CustomStringConvertible {
        let price, qty, commission, commissionAsset: String
        let tradeId: Int
        
        var description: String {
            "price: \((Double(price) ?? 0.0).string(maxFractionDigits: 8)), qty: \((Double(qty) ?? 0.0).string(maxFractionDigits: 8)), comm: \((Double(commission) ?? 0.0).string(maxFractionDigits: 8)), commAsset: \(commissionAsset)"
        }
    }
    
    struct ResponseError: Codable, CustomStringConvertible {
        
        var description: String {
            "code: \(code), message: \(msg)"
        }
        
        let code: Decimal
        let msg: String
    }
    
    enum BinanceError: Error, CustomStringConvertible {
        case unexpected(message: String)
        case noData
        
        var description: String {
            switch self {
            case .unexpected(let message):
                return message
            case .noData:
                return "No Data"
            }
        }
    }
    
    func newOrder(
        symbol: String,
        side: OrderSide,
        type: OrderType,
        quantity: Double,
        quoteOrderQty: Double,
        newOrderRespType: OrderResponseType
    ) async throws -> NewOrderResponse {
        let url: URL
        switch side {
        case .baseToQuote:
            url = URL(string: "https://api.binance.com/api/v3/order?symbol=\(symbol)&side=\(side.rawValue)&type=\(type.rawValue)&quantity=\(quantity)&newOrderRespType=\( newOrderRespType.rawValue)")!
        case .quoteToBase:
            url = URL(string: "https://api.binance.com/api/v3/order?symbol=\(symbol)&side=\(side.rawValue)&type=\(type.rawValue)&quoteOrderQty=\(quoteOrderQty)&newOrderRespType=\( newOrderRespType.rawValue)")!
        case .unknown:
            throw BinanceError.unexpected(message: "wrong order")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        signRequest(&request)
        
        let (data, _) = try await URLSession.shared.asyncData(from: request)
        
        return try JSONDecoder().decode(NewOrderResponse.self, from: data)
    }
    
    // MARK: - Orderbook
    
    
}

// MARK: - Helpers

private extension BinanceAPIService {
    
    func addApiKeyHeader(_ request: inout URLRequest) -> Void {
        request.addValue(apiKeyString, forHTTPHeaderField: "X-MBX-APIKEY")
    }
    
    func signRequest(_ request: inout URLRequest) -> Void {
        addApiKeyHeader(&request)
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        request.url = request.url?.appending("timestamp", value: "\(timestamp)")
        guard let query = request.url?.query else {
            fatalError("query should be here!")
        }
        let symmetricKey = SymmetricKey(data: secretString.data(using: .utf8)!)
        let signature = HMAC<SHA256>.authenticationCode(for: query.data(using: .utf8)!, using: symmetricKey)
        let signatureString = Data(signature).map { String(format: "%02hhx", $0) }.joined()
        request.url = request.url?.appending("signature", value: signatureString)
    }
    
}

