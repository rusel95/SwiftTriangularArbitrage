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

enum OrderSide: String {
    case quoteToBase = "BUY"
    case baseToQuote = "SELL"
    case unknown = "UNKNOWN"
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
    
    func getExchangeInfo() async throws -> [Symbol] {
        let url = URL(string: "https://api.binance.com/api/v3/exchangeInfo")!
        let (data, _) = try await URLSession.shared.asyncData(from: URLRequest(url: url))
        let response = try JSONDecoder().decode(ExchangeInfoResponse.self, from: data)
        return response.symbols
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
        request.sign(apiKeyString: apiKeyString, secretString: secretString)
        
        let (data, _) = try await URLSession.shared.asyncData(from: request)
        
        if let unexpectedResponseError = try? JSONDecoder().decode(ResponseError.self, from: data) {
            throw BinanceError.unexpected(message: unexpectedResponseError.msg)
        }
        
        return try JSONDecoder().decode(NewOrderResponse.self, from: data)
    }
    
    // MARK: - Orderbook
    
    
}
