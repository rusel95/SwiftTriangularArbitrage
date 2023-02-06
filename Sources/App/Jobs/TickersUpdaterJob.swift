//
//  File.swift
//  
//
//  Created by Ruslan on 29.12.2022.
//

import Queues
import Vapor
import telegram_vapor_bot

struct TickersUpdaterJob: ScheduledJob {
    
    typealias TriangularOpportinitiesDict = [String: TriangularOpportunity]
    
    private let bot: TGBotPrtcl
    private let stockExchange: StockExchange
    
    private let logger = Logger(label: "logger.artitrage.triangular")
    
    private let autoTradingService: AutoTradingService
    private let depthCheckService: DepthCheckService
    private let app: Application
    
    init(app: Application, bot: TGBotPrtcl, stockEchange: StockExchange) {
        self.app = app
        self.autoTradingService = AutoTradingService(app: app)
        self.depthCheckService = DepthCheckService(app: app)
        self.bot = bot
        self.stockExchange = stockEchange
    }
    
    func run(context: Queues.QueueContext) -> NIOCore.EventLoopFuture<Void> {
        return context.eventLoop.performWithTask {
            do {
                let bookTickersDict: [String: BookTicker]
                switch stockExchange {
                case .binance:
                    bookTickersDict = try await BinanceAPIService.shared
                        .getAllBookTickers()
                        .toDictionary(with: { $0.symbol })
                case .bybit:
                    bookTickersDict = try await ByBitAPIService.shared
                        .getTickers()
                        .map {
                            BookTicker(
                                symbol: $0.symbol,
                                askPrice: $0.askPrice,
                                askQty: "0",
                                bidPrice: $0.bidPrice,
                                bidQty: "0"
                            )
                        }
                        .toDictionary(with: { $0.symbol })
                case .huobi:
                    bookTickersDict = try await HuobiAPIService.shared
                        .getTickers()
                        .map {
                            BookTicker(
                                symbol: $0.symbol,
                                askPrice: String($0.ask),
                                askQty: String($0.askSize),
                                bidPrice: String($0.bid),
                                bidQty: String($0.bidSize)
                            )
                        }
                        .toDictionary(with: { $0.symbol })
                case .exmo:
                    bookTickersDict = try await ExmoAPIService.shared
                        .getBookTickers()
                        .toDictionary(with: { $0.symbol })
                case .kucoin:
                    bookTickersDict = try await KuCoinAPIService.shared
                        .getBookTickers()
                        .toDictionary(with: { $0.symbol })
                case .kraken:
                    bookTickersDict = try await KrakenAPIService.shared
                        .getBookTickers()
                        .toDictionary(with: { $0.symbol } )
                case .whitebit:
                    bookTickersDict = try await WhiteBitAPIService.shared
                        .getBookTickers()
                        .toDictionary(with: { $0.symbol })
                case .gateio:
                    bookTickersDict = try await GateIOAPIService.shared
                        .getBookTickers()
                        .toDictionary(with: { $0.symbol })
                }
                
                // NOTE: - Standart
                let standartTriangularsData = try Data(contentsOf: stockExchange.standartTriangularsStorageURL)
                let standartTriangulars = try JSONDecoder().decode([Triangular].self, from: standartTriangularsData)
                let standartSurfaceResults = RateCalculator.getSurfaceResults(
                    stockExchange: stockExchange,
                    mode: .standart,
                    triangulars: standartTriangulars,
                    bookTickersDict: bookTickersDict
                )
                let standartTriangularOpportunitiesDict = try await app.caches.memory.get(
                    stockExchange.standartTriangularOpportunityDictKey,
                    as: TriangularOpportinitiesDict.self
                ) ?? TriangularOpportinitiesDict()
                let newStandartTriangularOpportunitiesDict = RateCalculator.getActualTriangularOpportunitiesDict(
                    from: standartSurfaceResults,
                    currentOpportunities: standartTriangularOpportunitiesDict,
                    profitPercent: stockExchange.interestingProfit
                )
            
                let tradedStandartTriangularsDict = try await process(
                    triangularOpportunitiesDict: newStandartTriangularOpportunitiesDict,
                    mode: .standart,
                    stockExchange: stockExchange,
                    bookTickersDict: bookTickersDict
                )
                try await app.caches.memory.set(
                    stockExchange.stableTriangularOpportunityDictKey,
                    to: tradedStandartTriangularsDict
                )
            } catch {
                print("[\(stockExchange)] [tickers]: \(error.localizedDescription)")
            }
        }
    }
      
}

// MARK: - Helpers

private extension TickersUpdaterJob {
    
    func process(
        triangularOpportunitiesDict: [String: TriangularOpportunity],
        mode: Mode,
        stockExchange: StockExchange,
        bookTickersDict: [String: BookTicker] = [:]
    ) async throws -> [String: TriangularOpportunity] {
        // NOTE: - sending all Alerts to specific people separatly
        // TODO: - make a separate mode for autotrading - currently trading only for admin
        guard let adminUserInfo = UsersInfoProvider.shared.getUsersInfo(selectedMode: .alerting)
            .first(where: { $0.userId == 204251205 }) else { return triangularOpportunitiesDict }
        
        return await withTaskGroup(of: (String, TriangularOpportunity).self) { group in
            triangularOpportunitiesDict.forEach { key, opportunity in
                group.addTask {
                    guard opportunity.autotradeCicle == .pending else { return (key, opportunity) }
                    
                    do {
                        let depthCheckedTriangularOpportunity = try await depthCheckService.handle(
                            stockExchange: stockExchange,
                            opportunity: opportunity,
                            bookTickersDict: bookTickersDict,
                            for: adminUserInfo
                        )
                        let tradedTriangularOpportunity = try await autoTradingService.handle(
                            stockExchange: stockExchange,
                            opportunity: depthCheckedTriangularOpportunity,
                            bookTickersDict: bookTickersDict,
                            for: adminUserInfo
                        )
                        let text = "[\(stockExchange.rawValue)] \(tradedTriangularOpportunity.tradingDescription) \n\nUpdated at: \(Date().readableDescription)"
                        if let updateMessageId = opportunity.updateMessageId {
                            let editParams: TGEditMessageTextParams = .init(
                                chatId: .chat(adminUserInfo.chatId),
                                messageId: updateMessageId,
                                inlineMessageId: nil,
                                text: text
                            )
                            var editParamsArray: [TGEditMessageTextParams] = try await app.caches.memory.get(
                                "editParamsArray",
                                as: [TGEditMessageTextParams].self
                            ) ?? []
                            
                            editParamsArray.append(editParams)
                            try await app.caches.memory.set("editParamsArray", to: editParamsArray)
                            return (key, opportunity)
                        } else {
                            let tgMessage = try? bot.sendMessage(params: .init(chatId: .chat(adminUserInfo.chatId), text: text)).wait()
                            opportunity.updateMessageId = tgMessage?.messageId ?? 0
                            return (key, opportunity)
                        }
                    } catch {
                        return (key, opportunity)
                    }
                }
            }
            
            return await group.reduce(into: [:]) { dictionary, result in
                dictionary[result.0] = result.1
            }
        }
    }
    
}
