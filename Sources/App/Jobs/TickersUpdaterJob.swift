//
//  File.swift
//  
//
//  Created by Ruslan on 29.12.2022.
//

import Queues
import Vapor
import telegram_vapor_bot

typealias TriangularOpportinitiesDict = [String: TriangularOpportunity]

struct TickersUpdaterJob: ScheduledJob {
    
    
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
            print("start")
            await process()
            try await Task.sleep(nanoseconds: 100_000_000)
            await process()
            try await Task.sleep(nanoseconds: 100_000_000)
            await process()
            try await Task.sleep(nanoseconds: 100_000_000)
            await process()
            try await Task.sleep(nanoseconds: 100_000_000)
            await process()
            print("end")
        }
    }
      
}

// MARK: - Helpers

private extension TickersUpdaterJob {
    
    func process() async {
        do {
            let startTime = CFAbsoluteTimeGetCurrent()
            let readStartTime = CFAbsoluteTimeGetCurrent()
            let standartTriangulars: [Triangular] = try await self.app.caches.memory.get(
                StockExchange.binance.standartTriangularsMemoryKey, as: [Triangular].self) ?? []
            let readDuration = String(format: "%.4f", CFAbsoluteTimeGetCurrent() - readStartTime)
            
            let calcStartTime = CFAbsoluteTimeGetCurrent()
            let standartFairResults = RateCalculator.shared.getFairResults(
                stockExchange: .binance,
                mode: .standart,
                triangulars: standartTriangulars,
                tradeableSymbolOrderbookDepths: TradeableSymbolOrderbookDepthsStorage.shared.tradeableSymbolOrderbookDepths
            )
            let standartTriangularOpportunitiesDict = try await self.app.caches.memory.get(
                StockExchange.binance.standartTriangularOpportunityDictKey,
                as: TriangularOpportinitiesDict.self
            ) ?? TriangularOpportinitiesDict()
            let newStandartTriangularOpportunitiesDict = RateCalculator.shared.getActualTriangularOpportunitiesDict(
                from: standartFairResults,
                currentOpportunities: standartTriangularOpportunitiesDict,
                profitPercent: StockExchange.binance.interestingProfit
            )
            let calcDuration = String(format: "%.4f", CFAbsoluteTimeGetCurrent() - calcStartTime)
//            var bookTickersDict: [String: BookTicker] = [:]
//            TradeableSymbolOrderbookDepthsStorage.shared.tradeableSymbolOrderbookDepths.forEach({ key, value in
//                bookTickersDict[key] = BookTicker(
//                    symbol: key,
//                    askPrice: value.orderbookDepth.asks.first?.first ?? "0.0",
//                    askQty: value.orderbookDepth.asks.first?[1] ?? "0.0",
//                    bidPrice: value.orderbookDepth.bids.first?.first ?? "0.0",
//                    bidQty: value.orderbookDepth.bids.first?[1] ?? "0.0"
//                )
//            })
//            let tradedStandartTriangularsDict = try await self.handleTrade(
//                triangularOpportunitiesDict: newStandartTriangularOpportunitiesDict,
//                stockExchange: StockExchange.binance,
//                bookTickersDict: bookTickersDict
//            )
            try await self.app.caches.memory.set(
                StockExchange.binance.standartTriangularOpportunityDictKey,
                to: newStandartTriangularOpportunitiesDict
            )
            standartFairResults
                .filter { $0.profitPercent > 0.2 }
                .forEach { fairResult in
                    print(fairResult.description)
                }
            let duration = String(format: "%.4f", CFAbsoluteTimeGetCurrent() - startTime)
            print("All \(duration), calc: \(calcDuration), read: \(readDuration), \(Date().fullDateReadableDescription)")
        } catch {
            print("[\(stockExchange)] [calculation]: \(error.localizedDescription)")
        }
    }
    
    func handleTrade(
        triangularOpportunitiesDict: [String: TriangularOpportunity],
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
                        let tradedTriangularOpportunity = try await autoTradingService.handle(
                            stockExchange: stockExchange,
                            opportunity: opportunity,
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
