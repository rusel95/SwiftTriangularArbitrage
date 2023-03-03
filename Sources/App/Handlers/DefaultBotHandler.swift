//
//  DefaultBotHandler.swift
//  
//
//  Created by Ruslan Popesku on 22.06.2022.
//

import Vapor
import telegram_vapor_bot
import Logging
import CoreFoundation

struct Request: Encodable {
    
    enum Method: String, Encodable {
        case subscribe = "SUBSCRIBE"
        case unsubscribe = "UNSUBSCRIBE"
    }
    
    let method: Method
    let params: [String]
    let id: UInt
}

struct TradeableSymbolOrderbookDepth: Codable {
    
    let tradeableSymbol: BinanceAPIService.Symbol
    let orderbookDepth: OrderbookDepth
    
}

final class DefaultBotHandlers {
    
    // MARK: - PROPERTIES
    
    private var logger = Logger(label: "handlers.logger")
    
    private var standartTriangularOpportunitiesDict: [String: TriangularOpportunity] = [:]
    private var stableTriangularOpportunitiesDict: [String: TriangularOpportunity] = [:]
    
    private var bybitStandartTriangularOpportunitiesDict: [String: TriangularOpportunity] = [:]
    private var bybitStableTriangularOpportunitiesDict: [String: TriangularOpportunity] = [:]
    
    private var huobiStandartTriangularOpportunitiesDict: [String: TriangularOpportunity] = [:]
    private var huobiStableTriangularOpportunitiesDict: [String: TriangularOpportunity] = [:]

    private let bot: TGBotPrtcl
    private let app: Application
    
    var unsubscribedParams: [BinanceAPIService.Symbol] = []
    var symbolsToSubscribe: [BinanceAPIService.Symbol] = []
    
    var lastRequestId: UInt = 1
    var lastSendDate: Date = Date()
    
    private let autoTradingService: AutoTradingService
    
    // MARK: - METHODS
    
    init(bot: TGBotPrtcl, app: Application) {
        self.bot = bot
        self.app = app
        self.autoTradingService = AutoTradingService(app: app)
        
        Task {
            let standartTriangularsData = try Data(contentsOf: StockExchange.binance.standartTriangularsStorageURL)
            let standartTriangulars = try JSONDecoder().decode([Triangular].self, from: standartTriangularsData)
            try await app.caches.memory.set(StockExchange.binance.standartTriangularsMemoryKey, to: standartTriangulars)
            
            let tradeableSymbols = try await BinanceAPIService().getExchangeInfo()
                .filter { $0.status == .trading && $0.isSpotTradingAllowed }
            
            self.symbolsToSubscribe = tradeableSymbols
                .filter { symbol in
                    return standartTriangulars.contains(where: { triangular in
                        triangular.pairA == symbol.symbol
                        || triangular.pairB == symbol.symbol
                        || triangular.pairC == symbol.symbol
                    })
                }
            
            await withTaskGroup(of: (symbol: BinanceAPIService.Symbol, depth: OrderbookDepth?).self) { [weak self] group in
                for symbolToSubscribe in self?.symbolsToSubscribe ?? [] {
                    group.addTask {
                        let orderboolDepth = try? await BinanceAPIService.shared.getOrderbookDepth(symbol: symbolToSubscribe.symbol, limit: 10)
                        return (symbolToSubscribe, orderboolDepth)
                    }
                }
                for await tuple in group {
                    guard let depth = tuple.depth else { return }
                    
                    TradeableSymbolOrderbookDepthsStorage.shared.tradeableSymbolOrderbookDepths[tuple.symbol.symbol] = TradeableSymbolOrderbookDepth(tradeableSymbol: tuple.symbol, orderbookDepth: depth)
                }
            }
            connectToWebSocket()
        }
    }
    
    func addHandlers(app: Vapor.Application) {
        commandStartHandler(app: app, bot: bot)
        commandStartTriangularArbitragingHandler(app: app, bot: bot)
        commandStartStableTriangularArbitragingHandler(app: app, bot: bot)
        commandStartAlertingHandler(app: app, bot: bot)
        commandStopHandler(app: app, bot: bot)
        commandTestHandler(app: app, bot: bot)
    }
    
    func connectToWebSocket() {
        for symbol in symbolsToSubscribe {
            let _ = WebSocket.connect(to: "wss://stream.binance.com:9443/ws/\(symbol.symbol.lowercased())@depth20@100ms", on: app.eventLoopGroup.next()) { ws in
                print(symbol.symbol)
                ws.onText { _, text in
                    guard let data = text.data(using: .utf8),
                          let orderbookDepth = try? JSONDecoder().decode(OrderbookDepth.self, from: data) else {
                        print(text)
                        return
                    }
                    TradeableSymbolOrderbookDepthsStorage.shared.tradeableSymbolOrderbookDepths[symbol.symbol] = TradeableSymbolOrderbookDepth(tradeableSymbol: symbol, orderbookDepth: orderbookDepth)
                }
                
                ws.onPing { ws in
                    ws.send(raw: Data(), opcode: .pong)
                }
                
                ws.onClose.whenComplete { result in
                    self.unsubscribedParams.append(symbol)
                    print("closed", symbol, self.unsubscribedParams.count)
                }
            }
        }
    }

}

// MARK: - HANDLERS

private extension DefaultBotHandlers {
    
    // MARK: /start
    
    func commandStartHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: ["/start"]) { update, bot in
            guard let chatId = update.message?.chat.id else { return }
           
            let infoMessage = """
            Hi, my name is Hari!
            
            I'm a telegram bot, made for finding and alerting about triangular arbitraging opportunities on Binance.
            I have a next modes:
                
            /standart_triangular_arbitraging - classic triangular arbitrage opportinitites on Binance;
            /stable_triangular_arbitraging - stable coin on the start and end of arbitrage;
            /start_alerting - mode for alerting about extra opportunities (>= \(StockExchange.binance.interestingProfit)% of profit)
            /stop - all modes are suspended;
            Hope to be useful
            
            While I'm still on development stage, please write to @rusel95 if any questions
            """
            _ = try? bot.sendMessage(params: .init(chatId: .chat(chatId), text: infoMessage))
        }
        bot.connection.dispatcher.add(handler)
    }
    
    // MARK: /start_triangular_arbitraging
    
    func commandStartTriangularArbitragingHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [BotMode.standartTriangularArtibraging.command]) { update, bot in
            guard let chatId = update.message?.chat.id, let user = update.message?.from else { return }
            
            let infoMessage = "[Standart] Binance Online Triangular Possibilities with profit >= 0 % (every \(Int(BotMode.standartTriangularArtibraging.jobInterval)) seconds update):\n"
            let explanationMessageFutute = try? bot.sendMessage(params: .init(chatId: .chat(chatId), text: infoMessage))
            explanationMessageFutute?.whenComplete({ _ in
                let editMessageFuture = try? bot.sendMessage(params: .init(chatId: .chat(chatId), text: "Updating.."))
                editMessageFuture?.whenComplete({ result in
                    let triangularArbitragingMessageId = try? result.get().messageId
                    UsersInfoProvider.shared.handleModeSelected(chatId: chatId,
                                                                user: user,
                                                                mode: .standartTriangularArtibraging,
                                                                standartTriangularArbitragingMessageId: triangularArbitragingMessageId)
                })
            })
        }
        bot.connection.dispatcher.add(handler)
    }
    
    // MARK: /stable_triangular_arbitraging
    
    func commandStartStableTriangularArbitragingHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [BotMode.stableTriangularArbritraging.command]) { update, bot in
            guard let chatId = update.message?.chat.id, let user = update.message?.from else { return }
            
            let infoMessage = "[Stable] Binance Online Triangular Possibilities with profit >= 0 % (every \(Int(BotMode.stableTriangularArbritraging.jobInterval)) seconds update):\n"
            let explanationMessageFutute = try? bot.sendMessage(params: .init(chatId: .chat(chatId), text: infoMessage))
            explanationMessageFutute?.whenComplete({ _ in
                let editMessageFuture = try? bot.sendMessage(params: .init(chatId: .chat(chatId), text: "Updating.."))
                editMessageFuture?.whenComplete({ result in
                    let stableTriangularArbitragingMessageId = try? result.get().messageId
                    UsersInfoProvider.shared.handleModeSelected(chatId: chatId,
                                                                user: user,
                                                                mode: .stableTriangularArbritraging,
                                                                stableTriangularArbitragingMessageId: stableTriangularArbitragingMessageId)
                })
            })
        }
        bot.connection.dispatcher.add(handler)
    }
    
    // MARK: /start_alerting
    
    func commandStartAlertingHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [BotMode.alerting.command]) { update, bot in
            guard let chatId = update.message?.chat.id, let user = update.message?.from else { return }
            
            do {
                let text = "Starting alerting about opportunities with >= \(StockExchange.binance.interestingProfit)% profitability"
                _ = try bot.sendMessage(params: .init(chatId: .chat(chatId), text: text))
                UsersInfoProvider.shared.handleModeSelected(chatId: chatId, user: user, mode: .alerting)
            } catch (let botError) {
                print(botError.localizedDescription)
            }
        }
        bot.connection.dispatcher.add(handler)
    }
    
    // MARK: /stop
    
    func commandStopHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [BotMode.suspended.command]) { update, bot in
            guard let chatId = update.message?.chat.id else { return }
            
            UsersInfoProvider.shared.handleStopAllModes(chatId: chatId)
            _ = try? bot.sendMessage(params: .init(chatId: .chat(chatId), text: "All processes suspended"))
        }
        bot.connection.dispatcher.add(handler)
    }
    
    // MARK: /status
    
    func commandTestHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: ["/status"]) { update, bot in
            guard let chatId = update.message?.chat.id else { return }
            
            Task {
                do {
                    var text = UsersInfoProvider.shared.getAllUsersInfo()
                        .map { $0.description }
                        .joined(separator: "\n")
                    
                    for stockExchange in StockExchange.allCases {
                        // NOTE: - Standart
                        let standartTriangularsData = try Data(contentsOf: stockExchange.standartTriangularsStorageURL)
                        let standartTriangulars = try JSONDecoder().decode([Triangular].self, from: standartTriangularsData)
                        
                        // NOTE: - Stables
                        let stableTriangularsData = try Data(contentsOf: stockExchange.stableTriangularsStorageURL)
                        let stableTriangulars = try JSONDecoder().decode([Triangular].self, from: stableTriangularsData)
                        text.append("\n[\(stockExchange)] standart Triangulars: \(standartTriangulars.count), stable triangulars: \(stableTriangulars.count)")
                    }
                    
                    if let editParamsArray: [TGEditMessageTextParams] = try? await app.caches.memory.get(
                        "editParamsArray",
                        as: [TGEditMessageTextParams].self
                    ) {
                        text.append("\nTo Update: \(editParamsArray.count)")
                    }
                    
                    text.append("\n\(String().getMemoryUsedMegabytes())")
                  
                    _ = try bot.sendMessage(params: .init(chatId: .chat(chatId), text: text))
                } catch {
                    _ = try bot.sendMessage(params: .init(chatId: .chat(chatId), text: error.localizedDescription))
                }
            }
        }
        bot.connection.dispatcher.add(handler)
    }
    
}
