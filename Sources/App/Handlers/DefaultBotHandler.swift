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

final class DefaultBotHandlers {
    
    // MARK: - PROPERTIES
    
    static let shared = DefaultBotHandlers()
    
    private var logger = Logger(label: "handlers.logger")
    
    private var lastAlertingEvents: [String: Date] = [:]
    
    private let interestingProfitPercent: Double = 0.3

    // MARK: - METHODS
    
    func addHandlers(app: Vapor.Application, bot: TGBotPrtcl) {
        commandStartHandler(app: app, bot: bot)
        commandStartTriangularArbitragingHandler(app: app, bot: bot)
        commandStartStableTriangularArbitragingHandler(app: app, bot: bot)
        commandStartAlertingHandler(app: app, bot: bot)
        commandStopHandler(app: app, bot: bot)
        commandTestHandler(app: app, bot: bot)
        
        startTriangularArbitragingMonitoring(bot: bot)
        startStableTriangularArbitragingMonitoring(bot: bot)
    }

    
    func startTriangularArbitragingMonitoring(bot: TGBotPrtcl) {
        Jobs.add(interval: .seconds(BotMode.standartTriangularArtibraging.jobInterval)) { [weak self] in
            ArbitrageCalculator.shared.getSurfaceResults(for: .standart) { surfaceResults, statusText in
                guard let self = self, let surfaceResults = surfaceResults else { return }

                let text = surfaceResults
                    .sorted(by: { $0.profitPercent > $1.profitPercent })
                    .prefix(10)
                    .map { $0.description }
                    .joined(separator: "\n")
                    .appending(statusText)
                    .appending("\nUp to date as of: \(Date().readableDescription)")
                
                UsersInfoProvider.shared.getUsersInfo(selectedMode: .standartTriangularArtibraging).forEach { userInfo in
                    do {
                        if let triangularArbitragingMessageId = userInfo.triangularArbitragingMessageId {
                            let editParams: TGEditMessageTextParams = .init(chatId: .chat(userInfo.chatId),
                                                                            messageId: triangularArbitragingMessageId,
                                                                            inlineMessageId: nil,
                                                                            text: text)
                            _ = try bot.editMessageText(params: editParams)
                        } else {
                            _ = try bot.sendMessage(params: .init(chatId: .chat(userInfo.chatId), text: text))
                        }
                        
                    } catch (let botError) {
                        self.logger.report(error: botError)
                    }
                }
                
                let extraResultsText = surfaceResults
                    .filter { $0.profitPercent >= self.interestingProfitPercent }
                    .sorted(by: { $0.profitPercent > $1.profitPercent })
                    .prefix(10)
                    .map { $0.description }
                    .joined(separator: "\n")
                UsersInfoProvider.shared.getUsersInfo(selectedMode: .alerting).forEach { userInfo in
                    do {
                        if extraResultsText.isEmpty == false {
                            _ = try bot.sendMessage(params: .init(chatId: .chat(userInfo.chatId), text: extraResultsText))
                        }
                    } catch (let botError) {
                        self.logger.report(error: botError)
                    }
                }
            }
        }
    }
    
    func startStableTriangularArbitragingMonitoring(bot: TGBotPrtcl) {
        Jobs.add(interval: .seconds(BotMode.stableTriangularArbritraging.jobInterval)) { [weak self] in
            ArbitrageCalculator.shared.getSurfaceResults(for: .stable) { surfaceResults, statusText in
                guard let self = self, let surfaceResults = surfaceResults else { return }

                let text = surfaceResults
                    .sorted(by: { $0.profitPercent > $1.profitPercent })
                    .prefix(10)
                    .map { $0.description }
                    .joined(separator: "\n")
                    .appending(statusText)
                    .appending("\nUp to date as of: \(Date().readableDescription)")
                
                UsersInfoProvider.shared.getUsersInfo(selectedMode: .stableTriangularArbritraging).forEach { userInfo in
                    do {
                        if let triangularArbitragingMessageId = userInfo.stableTriangularArbitragingMessageId {
                            let editParams: TGEditMessageTextParams = .init(chatId: .chat(userInfo.chatId),
                                                                            messageId: triangularArbitragingMessageId,
                                                                            inlineMessageId: nil,
                                                                            text: text)
                            _ = try bot.editMessageText(params: editParams)
                        } else {
                            _ = try bot.sendMessage(params: .init(chatId: .chat(userInfo.chatId), text: text))
                        }
                        
                    } catch (let botError) {
                        self.logger.report(error: botError)
                    }
                }
                
                let extraResultsText = surfaceResults
                    .filter { $0.profitPercent >= self.interestingProfitPercent }
                    .sorted(by: { $0.profitPercent > $1.profitPercent })
                    .prefix(10)
                    .map { $0.description }
                    .joined(separator: "\n")
                UsersInfoProvider.shared.getUsersInfo(selectedMode: .alerting).forEach { userInfo in
                    do {
                        if extraResultsText.isEmpty == false {
                            _ = try bot.sendMessage(params: .init(chatId: .chat(userInfo.chatId), text: extraResultsText))
                        }
                    } catch (let botError) {
                        self.logger.report(error: botError)
                    }
                }
            }
        }
    }

}

// MARK: - HANDLERS

private extension DefaultBotHandlers {
    
    // MARK: /start
    
    func commandStartHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: ["/start"]) { [weak self] update, bot in
            guard let self = self, let chatId = update.message?.chat.id else { return }
           
            let infoMessage = """
            Hi, my name is Hari!
            
            I'm a telegram bot, made for finding and alerting about triangular arbitraging opportunities on Binance.
            I have a next modes:
                
            /start_triangular_arbitraging - mode for watching on current triangular arbitrage opportinitites on Binance;
            /start_stable_triangular_arbitraging - mode for watching on current triangular arbitrage opportinitites on Binance where starting coin is stable;
            /start_alerting - mode for alerting about extra opportunities (>= \(self.interestingProfitPercent)% of profit)
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
        let handler = TGCommandHandler(commands: [BotMode.standartTriangularArtibraging.command]) { [weak self] update, bot in
            guard let self = self, let chatId = update.message?.chat.id, let user = update.message?.from else { return }
            
            do {
                if UsersInfoProvider.shared.getUsersInfo(selectedMode: .standartTriangularArtibraging).contains(where: { $0.chatId == chatId }) {
                    _ = try bot.sendMessage(params: .init(chatId: .chat(chatId), text: "Already working - you can stop be clicking command /stop"))
                } else {
                    let infoMessage = "Binance Online Triangular Possibilities with profit >= 0 % (every \(Int(BotMode.standartTriangularArtibraging.jobInterval)) seconds update):\n"
                    let explanationMessageFutute = try? bot.sendMessage(params: .init(chatId: .chat(chatId), text: infoMessage))
                    explanationMessageFutute?.whenComplete({ _ in
                        let editMessageFuture = try? bot.sendMessage(params: .init(chatId: .chat(chatId), text: "Updating.."))
                        editMessageFuture?.whenComplete({ result in
                            let triangularArbitragingMessageId = try? result.get().messageId
                            UsersInfoProvider.shared.handleModeSelected(chatId: chatId,
                                                                        user: user,
                                                                        mode: .standartTriangularArtibraging,
                                                                        triangularArbitragingMessageId: triangularArbitragingMessageId)
                        })
                    })
                }
            } catch (let botError) {
                self.logger.report(error: botError)
            }
        }
        bot.connection.dispatcher.add(handler)
    }
    
    // MARK: /start_stable_triangular_arbitraging
    
    func commandStartStableTriangularArbitragingHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [BotMode.stableTriangularArbritraging.command]) { [weak self] update, bot in
            guard let self = self, let chatId = update.message?.chat.id, let user = update.message?.from else { return }
            
            do {
                if UsersInfoProvider.shared.getUsersInfo(selectedMode: .stableTriangularArbritraging).contains(where: { $0.chatId == chatId }) {
                    _ = try bot.sendMessage(params: .init(chatId: .chat(chatId), text: "Already working - you can stop be clicking command /stop"))
                } else {
                    let infoMessage = "Binance Online Triangular Possibilities (limited with start Stables) with profit >= 0 % (every \(Int(BotMode.stableTriangularArbritraging.jobInterval)) seconds update):\n"
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
            } catch (let botError) {
                self.logger.report(error: botError)
            }
        }
        bot.connection.dispatcher.add(handler)
    }
    
    // MARK: /start_alerting
    
    func commandStartAlertingHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [BotMode.alerting.command]) { [weak self] update, bot in
            guard let self = self, let chatId = update.message?.chat.id, let user = update.message?.from else { return }
            
            do {
                if UsersInfoProvider.shared.getUsersInfo(selectedMode: .alerting).contains(where: { $0.chatId == chatId }) {
                    _ = try bot.sendMessage(params: .init(chatId: .chat(chatId), text: "Already working, you can stop by tapping on command /stop"))
                } else {
                    let text = """
                    Started hunting on triangular arbitrage opportunities with >= \(self.interestingProfitPercent)% profitability
                    """
                    _ = try bot.sendMessage(params: .init(chatId: .chat(chatId), text: text))
                    UsersInfoProvider.shared.handleModeSelected(chatId: chatId, user: user, mode: .alerting)
                }
            } catch (let botError) {
                self.logger.report(error: botError)
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
        let handler = TGCommandHandler(commands: ["/status"]) { [weak self] update, bot in
            guard let self = self, let chatId = update.message?.chat.id else { return }
            
            let usersDescription = UsersInfoProvider.shared.getAllUsersInfo()
                .map { $0.description }
                .joined(separator: "\n")
            
            let text = "Users:\n\(usersDescription)\n"
            do {
                _ = try bot.sendMessage(params: .init(chatId: .chat(chatId), text: text))
            } catch (let botError) {
                self.logger.report(error: botError)
            }
        }
        bot.connection.dispatcher.add(handler)
    }
    
}
