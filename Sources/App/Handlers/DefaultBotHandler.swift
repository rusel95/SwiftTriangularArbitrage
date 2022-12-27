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

    private let arbitrageCalculatorService = ArbitrageCalculatorService()
    private let autoTradingService: AutoTradingService
    private let bot: TGBotPrtcl
    
    private let printQueue = OperationQueue()
    private let printBreakTime: TimeInterval = 3.0
    
    // MARK: - METHODS
    
    init(bot: TGBotPrtcl, app: Application) {
        self.bot = bot
        self.autoTradingService = AutoTradingService(app: app)
        
        arbitrageCalculatorService.priceChangeHandlerDelegate = self
        printQueue.maxConcurrentOperationCount = 1
        
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
            self?.arbitrageCalculatorService.getSurfaceResults(
                for: .standart,
                stockExchange: .binance
            ) { [weak self] surfaceResults, statusText in
                guard let self = self, let surfaceResults = surfaceResults else { return }
                
                let text = surfaceResults
                    .map { $0.description }
                    .joined(separator: "\n")
                    .appending(statusText)
                    .appending("\nUp to date as of: \(Date().readableDescription)")
                
                // NOTE: - sending all info to specific people separatly
                UsersInfoProvider.shared.getUsersInfo(selectedMode: .standartTriangularArtibraging).forEach { userInfo in
                    if let standartTriangularArbitragingMessageId = userInfo.standartTriangularArbitragingMessageId {
                        let editParams: TGEditMessageTextParams = .init(chatId: .chat(userInfo.chatId),
                                                                        messageId: standartTriangularArbitragingMessageId,
                                                                        inlineMessageId: nil,
                                                                        text: text)
                        self.printQueue.addOperation { [weak self] in
                            guard let self = self else { return }
                            
                            do {
                                _ = try self.bot.editMessageText(params: editParams)
                                Thread.sleep(forTimeInterval: self.printBreakTime)
                            } catch (let botError) {
                                self.logger.report(error: botError)
                            }
                        }
                    } else {
                        self.printQueue.addOperation { [weak self] in
                            guard let self = self else { return }
                            do {
                                _ = try bot.sendMessage(params: .init(chatId: .chat(userInfo.chatId), text: text))
                                Thread.sleep(forTimeInterval: self.printBreakTime)
                            } catch (let botError) {
                                self.logger.report(error: botError)
                            }
                        }
                    }
                }
            }
        }
    }
    
    func startStableTriangularArbitragingMonitoring(bot: TGBotPrtcl) {
        Jobs.add(interval: .seconds(BotMode.stableTriangularArbritraging.jobInterval)) { [weak self] in
            self?.arbitrageCalculatorService.getSurfaceResults(
                for: .stable,
                stockExchange: .binance
            ) { surfaceResults, statusText in
                guard let self = self, let surfaceResults = surfaceResults else { return }

                let text = surfaceResults
                    .map { $0.description }
                    .joined(separator: "\n")
                    .appending(statusText)
                    .appending("\nUp to date as of: \(Date().readableDescription)")
                
                UsersInfoProvider.shared.getUsersInfo(selectedMode: .stableTriangularArbritraging).forEach { userInfo in
                    if let triangularArbitragingMessageId = userInfo.stableTriangularArbitragingMessageId {
                        let editParams: TGEditMessageTextParams = .init(chatId: .chat(userInfo.chatId),
                                                                        messageId: triangularArbitragingMessageId,
                                                                        inlineMessageId: nil,
                                                                        text: text)
                        self.printQueue.addOperation { [weak self] in
                            guard let self = self else { return }
                            
                            do {
                                _ = try self.bot.editMessageText(params: editParams)
                                Thread.sleep(forTimeInterval: self.printBreakTime)
                            } catch (let botError) {
                                self.logger.report(error: botError)
                            }
                        }
                    } else {
                        self.printQueue.addOperation { [weak self] in
                            guard let self = self else { return }
                            
                            do { _ = try self.bot.sendMessage(params: .init(chatId: .chat(userInfo.chatId), text: text))
                                Thread.sleep(forTimeInterval: self.printBreakTime)
                            } catch (let botError) {
                                self.logger.report(error: botError)
                            }
                            
                        }
                    }
                }
            }
        }
    }

}

// MARK: - PriceChangeHandler

extension DefaultBotHandlers: PriceChangeDelegate {
    
    func binancePricesDidChange() {
        arbitrageCalculatorService.getSurfaceResults(
            for: .standart,
            stockExchange: .binance
        ) { [weak self] surfaceResults, statusText in
            guard let self = self, let surfaceResults = surfaceResults else { return }
            
            self.standartTriangularOpportunitiesDict = self.getActualTriangularOpportunities(
                from: surfaceResults,
                currentOpportunities: self.standartTriangularOpportunitiesDict,
                profitPercent: ArbitrageCalculatorService.Mode.standart.interestingProfitabilityPercent
            )
            self.alertUsers(
                for: .standart,
                stockExchange: .binance,
                with: self.standartTriangularOpportunitiesDict
            )
        }
        
        arbitrageCalculatorService.getSurfaceResults(
            for: .stable,
            stockExchange: .binance
        ) { [weak self] surfaceResults, statusText in
            guard let self = self, let surfaceResults = surfaceResults else { return }
            
            self.stableTriangularOpportunitiesDict = self.getActualTriangularOpportunities(
                from: surfaceResults,
                currentOpportunities: self.stableTriangularOpportunitiesDict,
                profitPercent: ArbitrageCalculatorService.Mode.stable.interestingProfitabilityPercent
            )
            self.alertUsers(
                for: .stable,
                stockExchange: .binance,
                with: self.stableTriangularOpportunitiesDict
            )
        }
    }
    
    func bybitPricesDidChange() {
        arbitrageCalculatorService.getSurfaceResults(
            for: .standart,
            stockExchange: .bybit
        ) { [weak self] surfaceResults, statusText in
            guard let self = self, let surfaceResults = surfaceResults else { return }
            
            self.bybitStandartTriangularOpportunitiesDict = self.getActualTriangularOpportunities(
                from: surfaceResults,
                currentOpportunities: self.bybitStandartTriangularOpportunitiesDict,
                profitPercent: -0.2
            )
            self.alertUsers(
                for: .standart,
                stockExchange: .bybit,
                with: self.bybitStandartTriangularOpportunitiesDict
            )
        }
        
        arbitrageCalculatorService.getSurfaceResults(
            for: .stable,
            stockExchange: .bybit
        ) { [weak self] surfaceResults, statusText in
            guard let self = self, let surfaceResults = surfaceResults else { return }
            
            self.bybitStableTriangularOpportunitiesDict = self.getActualTriangularOpportunities(
                from: surfaceResults,
                currentOpportunities: self.bybitStableTriangularOpportunitiesDict,
                profitPercent: -0.2
            )
            self.alertUsers(
                for: .stable,
                stockExchange: .bybit,
                with: self.bybitStableTriangularOpportunitiesDict
            )
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
            /start_alerting - mode for alerting about extra opportunities (>= \(ArbitrageCalculatorService.Mode.stable.interestingProfitabilityPercent)% of profit)
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
                    [Standart] opportunities with >= \(ArbitrageCalculatorService.Mode.standart.interestingProfitabilityPercent)% profitability
                    [Stable] opportunities with >= \(ArbitrageCalculatorService.Mode.stable.interestingProfitabilityPercent)% profitability
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
        for mode: ArbitrageCalculatorService.Mode,
        stockExchange: StockExchange,
        with triangularOpportunitiesDict: [String: TriangularOpportunity]
    ) {
        // NOTE: - sending all Alerts to specific people separatly
        UsersInfoProvider.shared.getUsersInfo(selectedMode: .alerting).forEach { userInfo in
            switch stockExchange {
            case .binance:
                // TODO: - make a separate mode for autotrading - currently trading only for admin
                guard userInfo.userId == 204251205 else { return }
                
                triangularOpportunitiesDict.forEach { _, opportunity in
                    guard opportunity.autotradeCicle == .pending else { return }
                    
                    Task {
                        do {
                            let tradedTriangularOpportunity = try await autoTradingService.handle(
                                opportunity: opportunity,
                                for: userInfo
                            )
                            let text = tradedTriangularOpportunity.tradingDescription.appending("\nUpdated at: \(Date().readableDescription)")
                            if let updateMessageId = opportunity.updateMessageId {
                                let editParams: TGEditMessageTextParams = .init(
                                    chatId: .chat(userInfo.chatId),
                                    messageId: updateMessageId,
                                    inlineMessageId: nil,
                                    text: text
                                )
                                self.printQueue.addOperation { [weak self] in
                                    guard let self = self else { return }
                                    
                                    do {
                                        _ = try self.bot.editMessageText(params: editParams)
                                        print(self.printQueue.operationCount)
                                        Thread.sleep(forTimeInterval: self.printBreakTime)
                                    } catch (let botError) {
                                        self.logger.report(error: botError)
                                    }
                                }
                            } else {
                                self.printQueue.addOperation { [weak self] in
                                    guard let self = self else { return }
                                    
                                    do {
                                        let sendMessageFuture = try self.bot.sendMessage(params: .init(chatId: .chat(userInfo.chatId), text: text))
                                        sendMessageFuture.whenComplete { result in
                                            do {
                                                let triangularOpportunityMessageId = try result.get().messageId
                                                opportunity.updateMessageId = triangularOpportunityMessageId
                                            } catch (let botError) {
                                                self.logger.report(error: botError)
                                            }
                                        }
                                        print(self.printQueue.operationCount)
                                        Thread.sleep(forTimeInterval: self.printBreakTime)
                                    } catch (let botError) {
                                        self.logger.report(error: botError)
                                    }
                                }
                            }
                        } catch {
                            self.printQueue.addOperation { [weak self] in
                                guard let self = self else { return }
                                
                                do {
                                    let _ = try self.bot.sendMessage(params: .init(chatId: .chat(userInfo.chatId), text: error.localizedDescription))
                                    print(self.printQueue.operationCount)
                                    Thread.sleep(forTimeInterval: self.printBreakTime)
                                } catch (let botError) {
                                    self.logger.report(error: botError)
                                }
                            }
                        }
                    }
                }
            case .bybit:
                triangularOpportunitiesDict.forEach { _, opportunity in
                    printQueue.addOperation { [weak self] in
                        guard let self = self else { return }
                        
                        do {
                            let text = "!!!!!! Bybit: \(opportunity.description)"
                            _ = try self.bot.sendMessage(params: .init(chatId: .chat(userInfo.chatId), text: text))
                            print(self.printQueue.operationCount)
                            Thread.sleep(forTimeInterval: self.printBreakTime)
                        } catch (let botError) {
                            self.logger.report(error: botError)
                        }
                    }
                }
            }
        }
    }
    
}
