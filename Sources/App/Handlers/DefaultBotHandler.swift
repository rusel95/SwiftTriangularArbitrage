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

    private let arbitrageCalculator: ArbitrageCalculator = ArbitrageCalculator()
    private let autoTradingService: AutoTradingService = AutoTradingService()
    private let bot: TGBotPrtcl
    
    // MARK: - METHODS
    
    init(bot: TGBotPrtcl) {
        self.bot = bot
        arbitrageCalculator.priceChangeHandlerDelegate = self
    }
    
    func addHandlers(app: Vapor.Application) {
        commandStartHandler(app: app, bot: bot)
        commandStartTriangularArbitragingHandler(app: app, bot: bot)
        commandStartStableTriangularArbitragingHandler(app: app, bot: bot)
        commandStartAlertingHandler(app: app, bot: bot)
        commandStopHandler(app: app, bot: bot)
        commandTestHandler(app: app, bot: bot)
        
        startStandartTriangularArbitragingMonitoring(bot: bot)
        startStableTriangularArbitragingMonitoring(bot: bot)
    }

    
    func startStandartTriangularArbitragingMonitoring(bot: TGBotPrtcl) {
        Jobs.add(interval: .seconds(BotMode.standartTriangularArtibraging.jobInterval)) { [weak self] in
            self?.arbitrageCalculator.getSurfaceResults(for: .standart) { [weak self] surfaceResults, statusText in
                guard let self = self, let surfaceResults = surfaceResults else { return }
                
                let text = surfaceResults
                    .map { $0.description }
                    .joined(separator: "\n")
                    .appending(statusText)
                    .appending("\nUp to date as of: \(Date().readableDescription)")
                
                // NOTE: - sending all info to specific people separatly
                UsersInfoProvider.shared.getUsersInfo(selectedMode: .standartTriangularArtibraging).forEach { userInfo in
                    do {
                        if let standartTriangularArbitragingMessageId = userInfo.standartTriangularArbitragingMessageId {
                            let editParams: TGEditMessageTextParams = .init(chatId: .chat(userInfo.chatId),
                                                                            messageId: standartTriangularArbitragingMessageId,
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
            }
        }
    }
    
    func startStableTriangularArbitragingMonitoring(bot: TGBotPrtcl) {
        Jobs.add(interval: .seconds(BotMode.stableTriangularArbritraging.jobInterval)) { [weak self] in
            self?.arbitrageCalculator.getSurfaceResults(for: .stable) { surfaceResults, statusText in
                guard let self = self, let surfaceResults = surfaceResults else { return }

                let text = surfaceResults
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
            }
        }
    }

}

// MARK: - PriceChangeHandler

extension DefaultBotHandlers: PriceChangeDelegate {
    
    func priceDidChange() {
        arbitrageCalculator.getSurfaceResults(for: .standart) { [weak self] surfaceResults, statusText in
            guard let self = self, let surfaceResults = surfaceResults else { return }
            
            self.standartTriangularOpportunitiesDict = self.getActualTriangularOpportunities(
                from: surfaceResults,
                currentOpportunities: self.standartTriangularOpportunitiesDict,
                profitPercent: ArbitrageCalculator.Mode.standart.interestingProfitabilityPercent
            )
            self.alertUsers(for: .standart, with: self.standartTriangularOpportunitiesDict)
        }
        
        arbitrageCalculator.getSurfaceResults(for: .stable) { [weak self] surfaceResults, statusText in
            guard let self = self, let surfaceResults = surfaceResults else { return }
            
            self.stableTriangularOpportunitiesDict = self.getActualTriangularOpportunities(
                from: surfaceResults,
                currentOpportunities: self.stableTriangularOpportunitiesDict,
                profitPercent: ArbitrageCalculator.Mode.stable.interestingProfitabilityPercent
            )
            self.alertUsers(for: .stable, with: self.stableTriangularOpportunitiesDict)
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
            /start_alerting - mode for alerting about extra opportunities (>= \(ArbitrageCalculator.Mode.stable.interestingProfitabilityPercent)% of profit)
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
        let handler = TGCommandHandler(commands: [BotMode.alerting.command]) { [weak self] update, bot in
            guard let self = self, let chatId = update.message?.chat.id, let user = update.message?.from else { return }
            
            do {
                let text = """
                    Starting alerting about:
                    [Standart] opportunities with >= \(ArbitrageCalculator.Mode.standart.interestingProfitabilityPercent)% profitability
                    [Stable] opportunities with >= \(ArbitrageCalculator.Mode.stable.interestingProfitabilityPercent)% profitability
                    """
                _ = try bot.sendMessage(params: .init(chatId: .chat(chatId), text: text))
                UsersInfoProvider.shared.handleModeSelected(chatId: chatId, user: user, mode: .alerting)
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

// MARK: - Helpers

private extension DefaultBotHandlers {
    
    func getActualTriangularOpportunities(
        from surfaceResults: [SurfaceResult],
        currentOpportunities: [String: TriangularOpportunity],
        profitPercent: Double
    ) -> [String: TriangularOpportunity] {
        var updatedOpportunities: [String: TriangularOpportunity] = currentOpportunities
        
        let extraResults = surfaceResults
            .filter { $0.profitPercent >= profitPercent && $0.profitPercent < 100 }
            .sorted(by: { $0.profitPercent > $1.profitPercent })
        
        // Add/Update
        extraResults.forEach { surfaceResult in
            if let currentOpportunity = updatedOpportunities[surfaceResult.contractsDescription] {
                currentOpportunity.surfaceResults.append(surfaceResult)
            } else {
                updatedOpportunities[surfaceResult.contractsDescription] = TriangularOpportunity(contractsDescription: surfaceResult.contractsDescription, firstSurfaceResult: surfaceResult, updateMessageId: nil)
            }
        }
        
        // Remove opportunities, which became old
        return updatedOpportunities.filter {
            Double(Date().timeIntervalSince($0.value.latestUpdateDate)) < 30
        }
    }
    
    func alertUsers(
        for mode: ArbitrageCalculator.Mode,
        with triangularOpportunitiesDict: [String: TriangularOpportunity]
    ) {
        UsersInfoProvider.shared.getUsersInfo(selectedMode: .alerting).forEach { userInfo in
            // NOTE: - sending all Alerts to specific people separatly
            let group = DispatchGroup()
            // Update each user's opportunities to message
            var newUserOpportunities: [String: Int?] = [:]
            
            // Remove user's opportunities which are not presented at the moment
            triangularOpportunitiesDict.forEach { triangularOpportunity in
                group.enter()
                
                let currentUserOpportunityMessageId: Int?
                switch mode {
                case .standart:
                    currentUserOpportunityMessageId = userInfo.standartTriangularOpportunitiesMessagesInfo[triangularOpportunity.key] ?? nil
                case .stable:
                    currentUserOpportunityMessageId = userInfo.stableTriangularOpportunitiesMessagesInfo[triangularOpportunity.key] ?? nil
                }
                
                if let currentUserOpportunityMessageId = currentUserOpportunityMessageId {
                    let editParams: TGEditMessageTextParams = .init(chatId: .chat(userInfo.chatId),
                                                                    messageId: currentUserOpportunityMessageId,
                                                                    inlineMessageId: nil,
                                                                    text: triangularOpportunity.value.tradingDescription.appending("\nUpdated at: \(Date().readableDescription)"))
                    do {
                        _ = try bot.editMessageText(params: editParams)
                        newUserOpportunities[triangularOpportunity.key] = currentUserOpportunityMessageId
                        group.leave()
                    } catch (let botError) {
                        self.logger.report(error: botError)
                        group.leave()
                    }
                } else {
                    do {
                        let sendMessageFuture = try bot.sendMessage(params: .init(chatId: .chat(userInfo.chatId), text: triangularOpportunity.value.description))
                        sendMessageFuture.whenComplete { result in
                            do {
                                let triangularOpportunityMessageId = try result.get().messageId
                                triangularOpportunity.value.updateMessageId = triangularOpportunityMessageId
                                newUserOpportunities[triangularOpportunity.key] = triangularOpportunityMessageId
                                group.leave()
                            } catch (let botError) {
                                self.logger.report(error: botError)
                                group.leave()
                            }
                        }
                    } catch (let botError) {
                        self.logger.report(error: botError)
                        group.leave()
                    }
                }
            }
            group.notify(queue: .global()) { [weak self] in
                switch mode {
                case .standart:
                    userInfo.standartTriangularOpportunitiesMessagesInfo = newUserOpportunities
                case .stable:
                    userInfo.stableTriangularOpportunitiesMessagesInfo = newUserOpportunities
                }
                // TODO: - make a separate mode for autotrading - currently trading only for admin
                if userInfo.userId == 204251205 {
                    triangularOpportunitiesDict.forEach { _, opportunity in
                        self?.autoTradingService.handle(
                            triangularOpportunity: opportunity,
                            for: userInfo,
                            completion: { tradedTriangularOpportunity in
                                let text = tradedTriangularOpportunity.tradingDescription.appending("\nUpdated at: \(Date().readableDescription)")
                                if let updateMessageId = tradedTriangularOpportunity.updateMessageId {
                                    let editParams: TGEditMessageTextParams = .init(
                                        chatId: .chat(userInfo.chatId),
                                        messageId: updateMessageId,
                                        inlineMessageId: nil,
                                        text: text
                                    )
                                    _ = try? self?.bot.editMessageText(params: editParams)
                                } else {
                                    _ = try? self?.bot.sendMessage(
                                        params: .init(chatId: .chat(userInfo.chatId), text: text)
                                    )
                                }
                            })
                    }
                }
            }
        }
    }
    
}
