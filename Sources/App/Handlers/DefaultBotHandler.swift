//
//  DefaultBotHandler.swift
//  
//
//  Created by Ruslan Popesku on 22.06.2022.
//

import Vapor
import telegram_vapor_bot
import Jobs
import Logging
import CoreFoundation

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
    
    // MARK: - METHODS
    
    init(bot: TGBotPrtcl) {
        self.bot = bot
    }
    
    func addHandlers(app: Vapor.Application) {
        commandStartHandler(app: app, bot: bot)
        commandStartTriangularArbitragingHandler(app: app, bot: bot)
        commandStartStableTriangularArbitragingHandler(app: app, bot: bot)
        commandStartAlertingHandler(app: app, bot: bot)
        commandStopHandler(app: app, bot: bot)
        commandTestHandler(app: app, bot: bot)
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
                    
                    let editParamsArray: [TGEditMessageTextParams] = try await app.caches.memory.get(
                        "editParamsArray",
                        as: [TGEditMessageTextParams].self
                    ) ?? []
                    text.append("\n\(String().getMemoryUsedMegabytes())")
                    text.append("\nTo Update: \(editParamsArray.count)")
                    
                    _ = try bot.sendMessage(params: .init(chatId: .chat(chatId), text: text))
                } catch {
                    print(error.localizedDescription)
                }
            }
        }
        bot.connection.dispatcher.add(handler)
    }
    
}
