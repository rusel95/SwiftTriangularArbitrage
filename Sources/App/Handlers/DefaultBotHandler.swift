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

struct PricesInfo {
    let possibleSellPrice: Double
    let possibleBuyPrice: Double
}

struct SpreadInfo {
    let dirtySpread: Double
    let cleanSpread: Double
}

final class DefaultBotHandlers {
    
    // MARK: - PROPERTIES
    
    static let shared = DefaultBotHandlers()
    
    private var logger = Logger(label: "handlers.logger")
    // TODO: - move to each users settings
    // Stores Last Alert Date for each scheme - needed to send Alert with some periodisation
    private var lastAlertingEvents: [String: Date] = [:]
    
    // TODO: - move to constants
    private let resultsFormatDescription = "Крипто продажа(платіжний спосіб) - покупка(платіжний спосіб) | можлива ціна Продажі - Покупки | спред повний - чистий | чистий профіт у %"
    private let commandsDescription = """
        /where_to_buy - бот вiдповiсть де дешевше купити $ (або USDT, щоб потiм помiняти його на $);
        /start_trading - режим моніторингу p2p-ринку на Binance в режимi реального часу;
        /start_arbitraging - режим моніторинг арбітражних можливостей в режимі реального часу;
        /start_binance_triangular_arbitrage - режим моніторингу трикутного внутрішньобіржового арбітражу на Binance;
        /start_alerting - режим, завдяки якому я сповіщу тебе як тільки в якійсь зі схім торгівлі зявляється чудова дохідність (максимум одне повідомлення на одну схему за годину);
        /start_logging - режим логування всіх наявних можливостей с певною періодичність (треба для ретроспективного бачення особливостей ринку і його подальшого аналізу);
        /stop - зупинка всіх режимів (очікування);
        """
    private let tradingSchemes: [EarningScheme] = [
        .monobankUSDT_monobankUSDT,
        .privatbankUSDT_privabbankUSDT,
        .monobankBUSD_monobankUSDT,
        .privatbankBUSD_privatbankUSDT,
        .wiseUSDT_wiseUSDT
    ]
    
    private let alertingSchemes: [EarningScheme] = [
        .monobankUSDT_monobankUSDT,
        .privatbankUSDT_privabbankUSDT,
        .monobankBUSD_monobankUSDT,
        .privatbankBUSD_privatbankUSDT,
        .abankUSDT_abankUSDT,
        .pumbUSDT_pumbUSDT,
        .huobiUSDT_monobankUSDT,
        .monobankUSDT_huobiUSDT,
        .whiteBitUSDT_monobankUSDT,
        .monobankUSDT_whiteBitUSDT
    ]
    
    private let usdtArbitragingOpportunities: [Opportunity] = [
        .binance(.p2p(.monobankUSDT)),
        .binance(.spot(.usdt_uah)),
        .huobi(.usdt_uah),
        .whiteBit(.usdt_uah),
        .exmo(.usdt_uah),
        .kuna(.usdt_uah),
        .coinsbit(.usdt_uah),
        .betconix(.usdt_uah),
        .qmall(.usdt_uah),
        .btcTrade(.usdt_uah)
    ]
    
    private let btcArbitragingOpportunities: [Opportunity] = [
        .binance(.spot(.btc_uah)),
        .whiteBit(.btc_uah),
        .huobi(.btc_uah),
        .exmo(.btc_uah),
        .kuna(.btc_uah),
        .coinsbit(.btc_uah),
        .qmall(.btc_uah),
        .betconix(.btc_uah)
    ]
    
    private let usdBuyOpportunities: [Opportunity] = [
        .binance(.p2p(.monobankUSDT)),
        .binance(.spot(.usdt_uah)),
        .huobi(.usdt_uah),
        .whiteBit(.usdt_uah),
        .exmo(.usdt_uah),
        .kuna(.usdt_uah),
        .coinsbit(.usdt_uah),
        .betconix(.usdt_uah),
        .qmall(.usdt_uah),
        .minfin(.usd_uah),
        .btcTrade(.usdt_uah)
    ]
    
    // MARK: - METHODS
    
    func addHandlers(app: Vapor.Application, bot: TGBotPrtcl) {
        commandStartHandler(app: app, bot: bot)
        commandWhereToBuyHandler(app: app, bot: bot)
        commandStartTradingHandler(app: app, bot: bot)
        commandStartArbitragingHandler(app: app, bot: bot)
        commandStartTriangularArbitragingHandler(app: app, bot: bot)
        commandStartAlertingHandler(app: app, bot: bot)
        commandStartLoggingHandler(app: app, bot: bot)
        commandStopHandler(app: app, bot: bot)
        commandTestHandler(app: app, bot: bot)
        
        startTradingJob(bot: bot)
        startArbitragingMonitoring(bot: bot)
        startTriangularArbitragingMonitoring(bot: bot)
        startAlertingJob(bot: bot)
        startLoggingJob(bot: bot)
    }
    
    func startTradingJob(bot: TGBotPrtcl) {
        Jobs.add(interval: .seconds(BotMode.trading.jobInterval)) { [weak self] in
            let usersInfoWithTradingMode = UsersInfoProvider.shared.getUsersInfo(selectedMode: .trading)
            
            guard let self = self, usersInfoWithTradingMode.isEmpty == false else { return }
           
            self.getDescription(
                earningSchemes: self.tradingSchemes,
                completion: { [weak self] totalDescription in
                    usersInfoWithTradingMode.forEach { userInfo in
                        do {
                            if let editMessageId = userInfo.onlineUpdatesMessageId {
                                let text = "\(totalDescription)\nАктуально станом на \(Date().readableDescription)"
                                let editParams: TGEditMessageTextParams = .init(chatId: .chat(userInfo.chatId),
                                                                                messageId: editMessageId,
                                                                                inlineMessageId: nil,
                                                                                text: text)
                                _ = try bot.editMessageText(params: editParams)
                            } else {
                                _ = try bot.sendMessage(params: .init(chatId: .chat(userInfo.chatId), text: totalDescription))
                            }
                        } catch (let botError) {
                            self?.logger.report(error: botError)
                        }
                    }
                }
            )
        }
    }
    
    func startArbitragingMonitoring(bot: TGBotPrtcl) {
        Jobs.add(interval: .seconds(BotMode.arbitraging.jobInterval)) { [weak self] in
            let usersInfoWithArbitragingMode = UsersInfoProvider.shared.getUsersInfo(selectedMode: .arbitraging)
            
            guard let self = self, usersInfoWithArbitragingMode.isEmpty == false else { return }
            
            self.getOpportunitiesResults(for: self.usdtArbitragingOpportunities) { [weak self] opportunitiesResults in
                var arbitragingPricesInfoDescription: String = ""
                
                let sellOpportunitiesResults = opportunitiesResults
                    .filter { ($0.finalSellPrice ?? 0.0) != 0 }
                    .sorted { $0.finalSellPrice ?? 0.0 > $1.finalSellPrice ?? 0.0 }
                
                let buyOpportunitiesResults = opportunitiesResults
                    .filter { ($0.finalBuyPrice ?? 0.0) != 0 }
                    .sorted { $0.finalBuyPrice ?? 0.0 > $1.finalBuyPrice ?? 0.0 }
                
                arbitragingPricesInfoDescription.append("Можливості для продажі (VISA/MASTERCARD):\n")
                sellOpportunitiesResults.forEach { sellOpportunityResult in
                    let description = "\(sellOpportunityResult.opportunity.descriptionWithSpaces)|\((sellOpportunityResult.finalSellPrice ?? 0.0).toLocalCurrency())\n"
                    arbitragingPricesInfoDescription.append(description)
                }
                
                arbitragingPricesInfoDescription.append("\nМожливості для покупки (VISA/MASTERCARD):\n")
                buyOpportunitiesResults.forEach { buyOpportunityResult in
                    let description = "\(buyOpportunityResult.opportunity.descriptionWithSpaces)|\((buyOpportunityResult.finalBuyPrice ?? 0.0).toLocalCurrency())\n"
                    arbitragingPricesInfoDescription.append(description)
                }
                
                usersInfoWithArbitragingMode.forEach { userInfo in
                    let text = "\n\(arbitragingPricesInfoDescription)\nАктуально станом на \(Date().readableDescription)"
                    do {
                        if let arbitragingMessageId = userInfo.arbitragingMessageId {
                            let editParams: TGEditMessageTextParams = .init(chatId: .chat(userInfo.chatId),
                                                                            messageId: arbitragingMessageId,
                                                                            inlineMessageId: nil,
                                                                            text: text)
                            _ = try bot.editMessageText(params: editParams)
                        } else {
                            _ = try bot.sendMessage(params: .init(chatId: .chat(userInfo.chatId), text: text))
                        }
                    } catch (let botError) {
                        self?.logger.report(error: botError)
                    }
                }
            }
        }
    }
    
    func startTriangularArbitragingMonitoring(bot: TGBotPrtcl) {
        let usersInfoWithTriangularArbitragingMode = UsersInfoProvider.shared.getUsersInfo(selectedMode: .triangularArtibraging)
        
        Jobs.add(interval: .seconds(BotMode.triangularArtibraging.jobInterval)) { [weak self] in
            guard usersInfoWithTriangularArbitragingMode.isEmpty == false else { return }
            
            ArbitrageCalculator.shared.getSurfaceResults { surfaceResults, statusText in
                guard let surfaceResults = surfaceResults, surfaceResults.isEmpty == false else { return }

                let text = surfaceResults
                    .sorted(by: { $0.profitLossPercent > $1.profitLossPercent })
                    .prefix(10)
                    .map { $0.description }
                    .joined(separator: "\n")
                    .appending(statusText)
                    .appending("\nАктуально станом на \(Date().readableDescription)")
                
                let extraResultsText = surfaceResults
                    .filter { $0.profitLossPercent >= 0.8 }
                    .sorted(by: { $0.profitLossPercent > $1.profitLossPercent })
                    .prefix(10)
                    .map { $0.description }
                    .joined(separator: "\n")
                
                usersInfoWithTriangularArbitragingMode.forEach { userInfo in
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
                        if extraResultsText.isEmpty == false {
                            _ = try bot.sendMessage(params: .init(chatId: .chat(userInfo.chatId), text: extraResultsText))
                        }
                    } catch (let botError) {
                        self?.logger.report(error: botError)
                    }
                }
            }
        }
    }
    
    func startAlertingJob(bot: TGBotPrtcl) {
        Jobs.add(interval: .seconds(BotMode.alerting.jobInterval)) { [weak self] in
            let usersInfoWithAlertingMode = UsersInfoProvider.shared.getUsersInfo(selectedMode: .alerting)
            
            guard let self = self, usersInfoWithAlertingMode.isEmpty == false else { return }
            
            let chatsIds: [Int64] = usersInfoWithAlertingMode.map { $0.chatId }
            
            self.alertAboutProfitability(earningSchemes: self.alertingSchemes, chatsIds: chatsIds, bot: bot)
            sleep(10)
            
            self.alertAboutArbitrage(opportunities: self.usdtArbitragingOpportunities,
                                     chatsIds: chatsIds,
                                     valuableProfitPercent: 0.8,
                                     bot: bot)
            sleep(10)
            
            self.alertAboutArbitrage(opportunities: self.btcArbitragingOpportunities,
                                     chatsIds: chatsIds,
                                     valuableProfitPercent: 1.5,
                                     bot: bot)
        }
    }
    
    func startLoggingJob(bot: TGBotPrtcl) {
        Jobs.add(interval: .seconds(BotMode.logging.jobInterval)) { [weak self] in
            let usersInfoWithLoggingMode = UsersInfoProvider.shared.getUsersInfo(selectedMode: .logging)
            
            guard let self = self, usersInfoWithLoggingMode.isEmpty == false else { return }
            
            self.getDescription(earningSchemes: EarningScheme.allCases) { [weak self] totalDescription in
                usersInfoWithLoggingMode.forEach { userInfo in
                    do {
                        _ = try bot.sendMessage(params: .init(chatId: .chat(userInfo.chatId), text: totalDescription))
                    } catch (let botError) {
                        self?.logger.report(error: botError)
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
            Привіт, мене звати Пантелеймон!
            
            Я Телеграм-Бот, зроблений для допомоги у торгівлі на Binance P2P та пошуку нових потенційних можливостей для торгівлі/арбітражу на інших платформах. Список готових режимів роботи (декілька режимів можуть працювати одночасно):
            \(self.commandsDescription)
            Сподіваюся бути тобі корисним..
            
            Поки мене ще роблять, я можу тупить. Якшо так - пишіть за допомогую або з пропозиціями до @rusel95 або @AnhelinaGrigoryeva
            
            P.S. Вибачте за мій суржик, і за те шо туплю..
            """
            _ = try? bot.sendMessage(params: .init(chatId: .chat(chatId), text: infoMessage))
        }
        bot.connection.dispatcher.add(handler)
    }
    
    // MARK: /where_to_buy
    
    func commandWhereToBuyHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [BotMode.whereToBuy.command]) { [weak self] update, bot in
            guard let self = self, let chatId = update.message?.chat.id else { return }
            
            self.getOpportunitiesResults(for: self.usdBuyOpportunities) { opportunitiesResults in
                var buyPricesInfoDescription: String = ""
                
                let buyOpportunitiesResults = opportunitiesResults
                    .filter { ($0.finalBuyPrice ?? 0.0) != 0 }
                    .sorted { $0.finalBuyPrice ?? 0.0 < $1.finalBuyPrice ?? 0.0 }
                
                buyPricesInfoDescription.append("\n(VISA/MASTERCARD) Можливості для покупки $(з урахування всiх комісій):\n")
                
                buyOpportunitiesResults.forEach { buyOpportunityResult in
                    let description = "\(buyOpportunityResult.opportunity.descriptionWithSpaces)|   \((buyOpportunityResult.finalBuyPrice ?? 0.0).toLocalCurrency())   UAH/\(buyOpportunityResult.opportunity.mainAssetAPIDescription)\n"
                    buyPricesInfoDescription.append(description)
                }
                
                do {
                    _ = try bot.sendMessage(params: .init(chatId: .chat(chatId), text: buyPricesInfoDescription))
                }  catch (let botError) {
                    self.logger.report(error: botError)
                }
            }
            
        }
        bot.connection.dispatcher.add(handler)
    }
    
    // MARK: /start_trading
    
    func commandStartTradingHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [BotMode.trading.command]) { [weak self] update, bot in
            guard let self = self, let chatId = update.message?.chat.id, let user = update.message?.from else { return }
            
            if UsersInfoProvider.shared.getUsersInfo(selectedMode: .trading).contains(where: { $0.chatId == chatId }) {
                let infoMessage = "Та все й так пашу. Можешь мене зупинить якшо не нравиться /stop"
                do {
                    _ = try bot.sendMessage(params: .init(chatId: .chat(chatId), text: infoMessage))
                } catch (let botError) {
                    self.logger.report(error: botError)
                }
            } else {
                let infoMessage = "Тепер Ви будете бачите повідовлення, яке буде оновлюватися акутальними розцінками кожні \(Int(BotMode.trading.jobInterval)) секунд у наступному форматі:\n\(self.resultsFormatDescription)"
                let explanationMessageFutute = try? bot.sendMessage(params: .init(chatId: .chat(chatId), text: infoMessage))
                explanationMessageFutute?.whenComplete({ _ in
                    let editMessageFuture = try? bot.sendMessage(params: .init(chatId: .chat(chatId), text: "Оновлюю.."))
                    editMessageFuture?.whenComplete({ [weak self] result in
                        let onlineUpdatesMessageId = try? result.get().messageId
                        UsersInfoProvider.shared.handleModeSelected(
                            chatId: chatId,
                            user: user,
                            mode: .trading,
                            onlineUpdatesMessageId: onlineUpdatesMessageId
                        )
                        
                        guard let self = self else { return }
                        
                        self.getDescription(
                            earningSchemes: self.tradingSchemes,
                            completion: { [weak self] totalDescription in
                                let text = "\(totalDescription)\nАктуально станом на \(Date().readableDescription)"
                                let editParams: TGEditMessageTextParams = .init(chatId: .chat(chatId),
                                                                                messageId: onlineUpdatesMessageId,
                                                                                inlineMessageId: nil,
                                                                                text: text)
                                do {
                                    _ = try bot.editMessageText(params: editParams)
                                } catch (let botError) {
                                    self?.logger.report(error: botError)
                                }
                            }
                        )
                    })
                })
            }
        }
        bot.connection.dispatcher.add(handler)
    }
    
    // MARK: /start_arbitraging
    
    func commandStartArbitragingHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [BotMode.arbitraging.command]) { [weak self] update, bot in
            guard let self = self, let chatId = update.message?.chat.id, let user = update.message?.from else { return }
            
            do {
                if UsersInfoProvider.shared.getUsersInfo(selectedMode: .arbitraging).contains(where: { $0.chatId == chatId }) {
                    _ = try bot.sendMessage(params: .init(chatId: .chat(chatId), text: "Та все й так пашу. Можешь мене зупинить якшо не нравиться /stop"))
                } else {
                    let infoMessage = "Тепер Ви будете бачите повідовлення, яке буде оновлюватися акутальними арбiтражними цiнами кожні \(Int(BotMode.arbitraging.jobInterval)) секунд:\n"
                    
                    let explanationMessageFutute = try? bot.sendMessage(params: .init(chatId: .chat(chatId), text: infoMessage))
                    explanationMessageFutute?.whenComplete({ _ in
                        let editMessageFuture = try? bot.sendMessage(params: .init(chatId: .chat(chatId), text: "Оновлюю.."))
                        editMessageFuture?.whenComplete({ result in
                            let arbitragingMessageId = try? result.get().messageId
                            UsersInfoProvider.shared.handleModeSelected(chatId: chatId,
                                                                        user: user,
                                                                        mode: .arbitraging,
                                                                        arbitragingMessageId: arbitragingMessageId)
                        })
                    })
                }
            } catch (let botError) {
                self.logger.report(error: botError)
            }
        }
        bot.connection.dispatcher.add(handler)
    }
    
    // MARK: /start_triangular_arbitraging
    
    func commandStartTriangularArbitragingHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [BotMode.triangularArtibraging.command]) { [weak self] update, bot in
            guard let self = self, let chatId = update.message?.chat.id, let user = update.message?.from else { return }
            
            do {
                if UsersInfoProvider.shared.getUsersInfo(selectedMode: .triangularArtibraging).contains(where: { $0.chatId == chatId }) {
                    _ = try bot.sendMessage(params: .init(chatId: .chat(chatId), text: "Та все й так пашу. Можешь мене зупинить якшо не нравиться /stop"))
                } else {
                    let infoMessage = "Binance Трикутні арбитражні можливості з profit > 0.01 % (оновлення кожні \(Int(BotMode.triangularArtibraging.jobInterval)) секунд):\n"
                    let explanationMessageFutute = try? bot.sendMessage(params: .init(chatId: .chat(chatId), text: infoMessage))
                    explanationMessageFutute?.whenComplete({ _ in
                        let editMessageFuture = try? bot.sendMessage(params: .init(chatId: .chat(chatId), text: "Оновлюю.."))
                        editMessageFuture?.whenComplete({ result in
                            let triangularArbitragingMessageId = try? result.get().messageId
                            UsersInfoProvider.shared.handleModeSelected(chatId: chatId,
                                                                        user: user,
                                                                        mode: .triangularArtibraging,
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
    
    // MARK: /start_alerting
    
    func commandStartAlertingHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [BotMode.alerting.command]) { [weak self] update, bot in
            guard let self = self, let chatId = update.message?.chat.id, let user = update.message?.from else { return }
            
            do {
                if UsersInfoProvider.shared.getUsersInfo(selectedMode: .alerting).contains(where: { $0.chatId == chatId }) {
                    _ = try bot.sendMessage(params: .init(chatId: .chat(chatId), text: "Та все й так пашу. Можешь мене зупинить якшо не нравиться /stop"))
                } else {
                    let schemesFullDescription = self.alertingSchemes
                        .map { "\($0.shortDescription) >= \($0.valuableProfit) %" }
                        .joined(separator: "\n")
                    let opportunitiesFullDescription = self.usdtArbitragingOpportunities
                        .map { $0.description }
                        .joined(separator: "\n")
                    
                    let text = """
                    Полювання за НадКрутими можливостями розпочато! Як тільки, так сразу я тобі скажу.
                    
                    Слідкую за наступними звязками:
                    \(schemesFullDescription)
                    
                    Намагаюся знайти найращі можливості для Арбітражу для наступних можливостей покупки/продажі на:
                    \(opportunitiesFullDescription)
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
    
    // MARK: /start_Logging
    
    func commandStartLoggingHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [BotMode.logging.command]) { [weak self] update, bot in
            guard let self = self, let chatId = update.message?.chat.id, let user = update.message?.from else { return }
            
            if UsersInfoProvider.shared.getUsersInfo(selectedMode: .logging).contains(where: { $0.chatId == chatId }) {
                let infoMessage = "Та все й так пашу. Можешь мене зупинить якшо не нравиться /stop"
                do {
                    _ = try bot.sendMessage(params: .init(chatId: .chat(chatId), text: infoMessage))
                } catch (let botError) {
                    self.logger.report(error: botError)
                }
            } else {
                let infoMessage = "Тепер я буду кожні \(Int(BotMode.logging.jobInterval / 60.0)) хвалин відправляти тобі статус всіх торгових можливостей у форматі\n\(self.resultsFormatDescription)"
                do {
                    _ = try bot.sendMessage(params: .init(chatId: .chat(chatId), text: infoMessage))
                } catch (let botError) {
                    self.logger.report(error: botError)
                }
                UsersInfoProvider.shared.handleModeSelected(chatId: chatId, user: user, mode: .logging)
                self.getDescription(
                    earningSchemes: EarningScheme.allCases,
                    completion: { [weak self] totalDescription in
                        do {
                            _ = try bot.sendMessage(params: .init(chatId: .chat(chatId), text: totalDescription))
                        } catch (let botError) {
                            self?.logger.report(error: botError)
                        }
                    }
                )
            }
        }
        bot.connection.dispatcher.add(handler)
    }
    
    // MARK: /stop
    
    func commandStopHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [BotMode.suspended.command]) { update, bot in
            guard let chatId = update.message?.chat.id else { return }
            
            UsersInfoProvider.shared.handleStopAllModes(chatId: chatId)
            _ = try? bot.sendMessage(params: .init(chatId: .chat(chatId), text: "Ну і ладно, я всьо равно вже заморився.."))// "Now bot will have some rest.."))
        }
        bot.connection.dispatcher.add(handler)
    }
    
    // MARK: /test
    
    func commandTestHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: ["/test"]) { [weak self] update, bot in
            guard let self = self, let chatId = update.message?.chat.id else { return }
           
            let usersDescription = UsersInfoProvider.shared.getAllUsersInfo()
                .map { $0.description }
                .joined(separator: "\n")
            
            var arbitragingPricesInfodescription = ""
            self.getOpportunitiesResults(for: self.btcArbitragingOpportunities) { opportunitiesResults in
                opportunitiesResults.forEach { opportunityResult in
                    arbitragingPricesInfodescription.append("\(opportunityResult.opportunity.description)|\(opportunityResult.priceInfo.possibleSellPrice.toLocalCurrency())-\(opportunityResult.priceInfo.possibleBuyPrice.toLocalCurrency())|\((opportunityResult.finalSellPrice ?? 0.0).toLocalCurrency())-\((opportunityResult.finalBuyPrice ?? 0.0).toLocalCurrency())\n")
                }
                let text = "Users:\n\(usersDescription)\n\nArtitrage:\n\(arbitragingPricesInfodescription)"
                do {
                    _ = try bot.sendMessage(params: .init(chatId: .chat(chatId), text: text))
                } catch (let botError) {
                    self.logger.report(error: botError)
                }
            }
        }
        bot.connection.dispatcher.add(handler)
    }
    
}

// MARK: - HELPERS

private extension DefaultBotHandlers {
    
    func getDescription(earningSchemes: [EarningScheme], completion: @escaping(String) -> Void) {
        let earningShemesGroup = DispatchGroup()
        var potentialEarningResults: [(scheme: EarningScheme, description: String)] = []
        earningSchemes.forEach { earningScheme in
            earningShemesGroup.enter()
            
            getPricesInfo(for: earningScheme) { pricesInfo in
                guard let pricesInfo = pricesInfo else {
                    potentialEarningResults.append((earningScheme, "No Prices for \(earningScheme)\n"))
                    earningShemesGroup.leave()
                    return
                }
        
                let description = self.getPrettyDescription(sellOpportunity: earningScheme.sellOpportunity,
                                                            buyOpportunity: earningScheme.buyOpportunity,
                                                            pricesInfo: pricesInfo)
                potentialEarningResults.append((earningScheme, description))
                earningShemesGroup.leave()
            }
        }
        
        earningShemesGroup.notify(queue: .global()) {
            let totalDescription = potentialEarningResults
                .sorted { $0.scheme.rawValue < $1.scheme.rawValue }
                .map { $0.description }
                .joined(separator: "\n")
            completion(totalDescription)
        }
    }
    
    func getPricesInfo(for earningScheme: EarningScheme, completion: @escaping(PricesInfo?) -> Void) {
        if earningScheme.sellOpportunity == earningScheme.buyOpportunity {
            getPricesInfo(for: earningScheme.sellOpportunity) { pricesInfo in
                completion(pricesInfo)
            }
        } else {
            var averagePossibleSellPrice: Double?
            var averagePossibleBuyPrice: Double?

            let priceInfoGroup = DispatchGroup()
            priceInfoGroup.enter()
            getPricesInfo(for: earningScheme.sellOpportunity) { pricesInfo in
                averagePossibleSellPrice = pricesInfo?.possibleSellPrice
                priceInfoGroup.leave()
            }
            
            priceInfoGroup.enter()
            getPricesInfo(for: earningScheme.buyOpportunity) { pricesInfo in
                averagePossibleBuyPrice = pricesInfo?.possibleBuyPrice
                priceInfoGroup.leave()
            }
            priceInfoGroup.notify(queue: .global()) { [weak self] in
                guard let possibleSellPrice = averagePossibleSellPrice else {
                    self?.logger.info(Logger.Message(stringLiteral: "NO possibleSellPrice for \(earningScheme.sellOpportunity.description)"))
                    completion(nil)
                    return
                }
                guard let possibleBuyPrice = averagePossibleBuyPrice else {
                    self?.logger.info(Logger.Message(stringLiteral: "NO possibleBuyPrice for \(earningScheme.buyOpportunity.description)"))
                    completion(nil)
                    return
                }
                
                completion(PricesInfo(possibleSellPrice: possibleSellPrice, possibleBuyPrice: possibleBuyPrice))
            }
        }
    }
    
    func getPricesInfo(for opportunity: Opportunity, completion: @escaping(PricesInfo?) -> Void) {
        switch opportunity {
        case .binance(let binanceOpportunity):
            switch binanceOpportunity {
            case .p2p(let binanceP2POpportunity):
                BinanceAPIService.shared.loadAdvertisements(
                    paymentMethod: binanceP2POpportunity.paymentMethod.apiDescription,
                    crypto: binanceP2POpportunity.mainAsset.apiDescription
                ) { [weak self] buyAdvs, sellAdvs, error in
                    guard let self = self, let buyAdvs = buyAdvs, let sellAdvs = sellAdvs else {
                        self?.logger.info(Logger.Message(stringLiteral: "NO PRICES FOR BINANCE P2P"))
                        completion(nil)
                        return
                    }
                    
                    let makersBuyPrices = self.getFilteredPrices(advs: sellAdvs, binanceOpportunity: binanceP2POpportunity)
                    let averagePossibleBuyPrice = makersBuyPrices.reduce(0.0, +) / Double(makersBuyPrices.count)
                    
                    let makersSellPrices = self.getFilteredPrices(advs: buyAdvs, binanceOpportunity: binanceP2POpportunity)
                    let averagePossibleSellPrice = makersSellPrices.reduce(0.0, +) / Double(makersSellPrices.count)
                    
                    completion(PricesInfo(possibleSellPrice: averagePossibleSellPrice, possibleBuyPrice: averagePossibleBuyPrice))
                }
            case .spot(let binanceSpotOpportunity):
                BinanceAPIService.shared.getBookTicker(symbol: binanceSpotOpportunity.paymentMethod.rawValue) { [weak self] ticker in
                    guard let possibleSellPrice = ticker?.sellPrice, let possibleBuyPrice = ticker?.buyPrice else {
                        self?.logger.info(Logger.Message(stringLiteral: "NO PRICES FOR BINANCE SPOT"))
                        completion(nil)
                        return
                    }
                    completion(PricesInfo(possibleSellPrice: possibleSellPrice, possibleBuyPrice: possibleBuyPrice))
                }
            }
           
        case .whiteBit(let opportunity):
            WhiteBitAPIService.shared.getOrderbook(paymentMethod: opportunity.paymentMethod.apiDescription) { [weak self] asks, bids, error in
                guard let possibleSellPrice = bids?.first, let possibleBuyPrice = asks?.first else {
                    self?.logger.info(Logger.Message(stringLiteral: "NO PRICES FOR WHITEBIT"))
                    completion(nil)
                    return
                }
                completion(PricesInfo(possibleSellPrice: possibleSellPrice, possibleBuyPrice: possibleBuyPrice))
            }
                
        case .huobi(let opportunity):
            HuobiAPIService.shared.getOrderbook(paymentMethod: opportunity.paymentMethod.apiDescription) { [weak self] asks, bids, error in
                guard let possibleSellPrice = bids.first, let possibleBuyPrice = asks.first else {
                    self?.logger.info(Logger.Message(stringLiteral: "NO PRICES FOR HUOBI"))
                    completion(nil)
                    return
                }
                completion(PricesInfo(possibleSellPrice: possibleSellPrice, possibleBuyPrice: possibleBuyPrice))
            }
            
        case .exmo(let exmoOpportunity):
            EXMOAPIService.shared.getOrderbook(assetsPair: exmoOpportunity.paymentMethod.apiDescription) { [weak self] askTop, bidTop, error in
                guard let possibleSellPrice = bidTop, let possibleBuyPrice = askTop else {
                    self?.logger.info(Logger.Message(stringLiteral: "NO PRICES FOR EXMO"))
                    completion(nil)
                    return
                }
                completion(PricesInfo(possibleSellPrice: possibleSellPrice, possibleBuyPrice: possibleBuyPrice))
            }
            
        case .kuna(let kunaOpportunity):
            KunaAPIService.shared.getOrderbook(paymentMethod: kunaOpportunity.paymentMethod.apiDescription) { [weak self] asks, bids, error in
                guard let possibleSellPrice = bids.first, let possibleBuyPrice = asks.first else {
                    self?.logger.info(Logger.Message(stringLiteral: "NO PRICES FOR KUNA"))
                    completion(nil)
                    return
                }
                completion(PricesInfo(possibleSellPrice: possibleSellPrice, possibleBuyPrice: possibleBuyPrice))
            }
            
        case .coinsbit(let coinsbitOpportunity):
            CoinsbitAPIService.shared.getTicker(market: coinsbitOpportunity.paymentMethod.apiDescription) { [weak self] ask, bid, error in
                guard let possibleSellPrice = bid, let possibleBuyPrice = ask else {
                    self?.logger.info(Logger.Message(stringLiteral: "NO PRICES FOR COINSBIT"))
                    completion(nil)
                    return
                }
                completion(PricesInfo(possibleSellPrice: possibleSellPrice, possibleBuyPrice: possibleBuyPrice))
            }
            
        case .betconix(let betconixOpportunity):
            BetconixAPIService.shared.getOrderbook(assetsPair: betconixOpportunity.paymentMethod.apiDescription) { [weak self] ask, bid, error in
                guard let possibleSellPrice = bid, let possibleBuyPrice = ask else {
                    self?.logger.info(Logger.Message(stringLiteral: "NO PRICES FOR BETCONIX"))
                    completion(nil)
                    return
                }
                completion(PricesInfo(possibleSellPrice: possibleSellPrice, possibleBuyPrice: possibleBuyPrice))
            }
        case .qmall(let qmallOpportunity):
            QMallAPIService.shared.getTicker(market: qmallOpportunity.paymentMethod.apiDescription) { [weak self] ask, bid, error in
                guard let possibleSellPrice = bid, let possibleBuyPrice = ask else {
                    self?.logger.info(Logger.Message(stringLiteral: "NO PRICES FOR QMALL"))
                    completion(nil)
                    return
                }
                completion(PricesInfo(possibleSellPrice: possibleSellPrice, possibleBuyPrice: possibleBuyPrice))
            }
            
        case .btcTrade(let btcTradeOpportunity):
            BTCTradeAPIService.shared.loadPriceInfo(ticker: btcTradeOpportunity.paymentMethod.apiDescription) { pricesInfo in
                completion(pricesInfo)
            } failure: { _ in
                completion(nil)
            }
            
        case .minfin(let minfinOpportunity):
            if let auction = MinfinService.shared.auctions?.first(where: { $0.type.rawValue == minfinOpportunity.paymentMethod.apiDescription }),
               let possibleSellPrice = Double(auction.info.bid),
               let possibleBuyPrice = Double(auction.info.ask)
            {
                completion(PricesInfo(possibleSellPrice: possibleSellPrice, possibleBuyPrice: possibleBuyPrice))
            } else {
                completion(nil)
            }
        }
    }
    
    func getFilteredPrices(advs: [BinanceAPIService.Adv], binanceOpportunity: Opportunity.Binance.P2P) -> [Double] {
        let arraySlice = advs
            .filter { Double($0.surplusAmount) ?? 0 >= binanceOpportunity.minSurplusAmount }
            .filter { Double($0.minSingleTransAmount) ?? 0 >= binanceOpportunity.minSingleTransAmount }
            .filter { Double($0.minSingleTransAmount) ?? 0 <= binanceOpportunity.maxSingleTransAmount }
            .compactMap { Double($0.price) }
            .compactMap { $0 }
            .prefix(binanceOpportunity.numberOfAdvsToConsider)
        return Array(arraySlice)
    }
    
}

// MARK: - ALERTING

private extension DefaultBotHandlers {
    
    func alertAboutProfitability(earningSchemes: [EarningScheme], chatsIds: [Int64], bot: TGBotPrtcl) {
        earningSchemes.forEach { [weak self] earningScheme in
            guard let self = self,
                  ((Date() - (self.lastAlertingEvents[earningScheme.shortDescription] ?? Date())).seconds.unixTime > Duration.hours(1).unixTime) || self.lastAlertingEvents[earningScheme.shortDescription] == nil
            else { return }
            
            getPricesInfo(for: earningScheme) { [weak self] pricesInfo in
                guard let self = self,
                      let pricesInfo = pricesInfo,
                      let spreadInfo = self.getSpreadInfo(sellOpportunity: earningScheme.sellOpportunity,
                                                          buyOpportunity: earningScheme.buyOpportunity,
                                                          pricesInfo: pricesInfo),
                      spreadInfo.cleanSpread > earningScheme.valuableProfit else { return }
                
                self.lastAlertingEvents[earningScheme.shortDescription] = Date()
                let description = self.getPrettyDescription(sellOpportunity: earningScheme.sellOpportunity,
                                                            buyOpportunity: earningScheme.buyOpportunity,
                                                            pricesInfo: pricesInfo)
                let text = "Профітна можливість!!! \(description)"
                
                chatsIds.forEach { chatId in
                    do {
                        _ = try bot.sendMessage(params: .init(chatId: .chat(chatId), text: text))
                    } catch (let botError) {
                        self.logger.report(error: botError)
                    }
                }
            }
        }
    }
    
    func alertAboutArbitrage(
        opportunities: [Opportunity],
        chatsIds: [Int64],
        valuableProfitPercent: Double,
        bot: TGBotPrtcl
    ) {
        getOpportunitiesResults(for: opportunities) { [weak self] opportunitiesResults in
            let biggestSellFinalPriceOpportunityResult = opportunitiesResults
                .filter { ($0.finalSellPrice ?? 0.0) != 0.0 }
                .sorted { $0.finalSellPrice ?? 0.0 > $1.finalSellPrice ?? 0.0 }
                .first
            
            let lowestBuyFinalPriceOpportunityResult = opportunitiesResults
                .filter { ($0.finalBuyPrice ?? 0.0) != 0.0 }
                .sorted { $0.finalBuyPrice ?? 0.0 < $1.finalBuyPrice ?? 0.0 }
                .first
            
            guard let self = self,
                  let biggestSellFinalPriceOpportunityResult = biggestSellFinalPriceOpportunityResult,
                  let lowestBuyFinalPriceOpportunityResult = lowestBuyFinalPriceOpportunityResult
            else { return }
            
            let currentArbitragePossibilityID = "\(biggestSellFinalPriceOpportunityResult.opportunity.paymentMethodDescription)-\(lowestBuyFinalPriceOpportunityResult.opportunity.paymentMethodDescription)"
           
            let pricesInfo = PricesInfo(possibleSellPrice: biggestSellFinalPriceOpportunityResult.priceInfo.possibleSellPrice,
                                        possibleBuyPrice: lowestBuyFinalPriceOpportunityResult.priceInfo.possibleBuyPrice)
            
            guard let spreadInfo = self.getSpreadInfo(sellOpportunity: biggestSellFinalPriceOpportunityResult.opportunity,
                                                      buyOpportunity: lowestBuyFinalPriceOpportunityResult.opportunity,
                                                      pricesInfo: pricesInfo) else {
                self.logger.info(Logger.Message(stringLiteral: "NO spreadInfo for sellOpportunity: \( biggestSellFinalPriceOpportunityResult.opportunity.description), buyOpportunity: \(lowestBuyFinalPriceOpportunityResult.opportunity.description)"))
                return
            }
            let profitPercent: Double = spreadInfo.cleanSpread / pricesInfo.possibleSellPrice * 100.0
            guard ((Date() - (self.lastAlertingEvents[currentArbitragePossibilityID] ?? Date())).seconds.unixTime > Duration.hours(1).unixTime ||
                   self.lastAlertingEvents[currentArbitragePossibilityID] == nil) &&
                    profitPercent > valuableProfitPercent else { return } // %
            
            self.lastAlertingEvents[currentArbitragePossibilityID] = Date()
            let prettyDescription = self.getPrettyDescription(sellOpportunity: biggestSellFinalPriceOpportunityResult.opportunity,
                                                              buyOpportunity: lowestBuyFinalPriceOpportunityResult.opportunity,
                                                              pricesInfo: pricesInfo)
            chatsIds.forEach { chatId in
                do {
                    _ = try bot.sendMessage(params: .init(chatId: .chat(chatId), text: "Арбітражна можливість: \(prettyDescription)"))
                } catch (let botError) {
                    self.logger.report(error: botError)
                }
            }
        }
    }
    
    func getOpportunitiesResults(for opportunities: [Opportunity], completion: @escaping([OpportunityResult]) -> Void) {
        let opportunitiesGroup = DispatchGroup()
        var opportunitiesResults: [OpportunityResult] = []
        opportunities.forEach { opportunity in
            opportunitiesGroup.enter()
            
            getPricesInfo(for: opportunity) { pricesInfo in
                guard let pricesInfo = pricesInfo else {
                    opportunitiesGroup.leave()
                    return
                }
        
                opportunitiesResults.append(OpportunityResult(opportunity: opportunity, priceInfo: pricesInfo))
                opportunitiesGroup.leave()
            }
        }
        opportunitiesGroup.notify(queue: .global()) {
            completion(opportunitiesResults)
        }
    }
    
}

// MARK: - HELPERS

private extension DefaultBotHandlers {
    
    func getPrettyDescription(sellOpportunity: Opportunity, buyOpportunity: Opportunity, pricesInfo: PricesInfo) -> String {
        let spreadInfo = getSpreadInfo(sellOpportunity: sellOpportunity, buyOpportunity: buyOpportunity, pricesInfo: pricesInfo)
        let cleanSpreadPercentString = (((spreadInfo?.cleanSpread ?? 0.0) / pricesInfo.possibleSellPrice) * 100).toLocalCurrency()
        
        return ("\(sellOpportunity.description)-\(buyOpportunity.description)|\(pricesInfo.possibleSellPrice.toLocalCurrency())-\(pricesInfo.possibleBuyPrice.toLocalCurrency())|\((spreadInfo?.dirtySpread ?? 0.0).toLocalCurrency())-\((spreadInfo?.cleanSpread ?? 0.0).toLocalCurrency())|\(cleanSpreadPercentString)%\n")
    }
    
    func getSpreadInfo(sellOpportunity: Opportunity, buyOpportunity: Opportunity, pricesInfo: PricesInfo) -> SpreadInfo? {
        guard let sellCommission = sellOpportunity.sellCommission, let buyCommission = buyOpportunity.buyCommission else {
            return nil
        }
        
        let dirtySpread = pricesInfo.possibleSellPrice - pricesInfo.possibleBuyPrice
        let sellComissionAmount = pricesInfo.possibleSellPrice * sellCommission / 100.0
        let buyCommissionAmount = pricesInfo.possibleBuyPrice * buyCommission / 100.0
        let cleanSpread = dirtySpread - sellComissionAmount - buyCommissionAmount
        return SpreadInfo(dirtySpread: dirtySpread, cleanSpread: cleanSpread)
    }
    
}
