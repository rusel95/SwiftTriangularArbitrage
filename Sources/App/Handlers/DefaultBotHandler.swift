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

typealias PricesInfo = (possibleSellPrice: Double, possibleBuyPrice: Double)
typealias SpreadInfo = (dirtySpread: Double, cleanSpread: Double)

struct OpportunityResult {
    
    let opportunity: Opportunity
    let priceInfo: PricesInfo
    
    var finalSellPrice: Double? {
        guard let sellCommission = opportunity.sellCommission else { return nil }
        
        return priceInfo.possibleSellPrice - (priceInfo.possibleSellPrice * (sellCommission) / 100.0)
    }
    
    var finalBuyPrice: Double? {
        guard let buyCommission = opportunity.buyCommission else { return nil }
        
        return priceInfo.possibleBuyPrice + (priceInfo.possibleBuyPrice * (buyCommission) / 100.0)
    }
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
        /start_trading - режим моніторингу основних схем торгівлі в режимі реального часу (відкриваємо і торгуємо);
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
    
    private let arbitragingOpportunities: [Opportunity] = [
        .binance(.p2p(.monobankUSDT)),
        .huobi(.usdtSpot),
        .whiteBit(.usdtSpot),
        .binance(.spot(.usdtUAH)),
        .exmo(.usdtUAHSpot),
        .kuna(.usdtUAHSpot),
        .coinsbit(.usdtUAHSpot)
    ]
    
    // MARK: - METHODS
    
    func addHandlers(app: Vapor.Application, bot: TGBotPrtcl) {
        commandStartHandler(app: app, bot: bot)
        commandStartTradingHandler(app: app, bot: bot)
        commandStartAlertingHandler(app: app, bot: bot)
        commandStartLoggingHandler(app: app, bot: bot)
        commandStopHandler(app: app, bot: bot)
        commandTestHandler(app: app, bot: bot)
        
        startTradingJob(bot: bot)
        startAlertingJob(bot: bot)
        startLoggingJob(bot: bot)
    }
    
    func startTradingJob(bot: TGBotPrtcl) {
        Jobs.add(interval: .seconds(Mode.trading.jobInterval)) { [weak self] in
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
    
    func startAlertingJob(bot: TGBotPrtcl) {
        Jobs.add(interval: .seconds(Mode.alerting.jobInterval)) { [weak self] in
            let usersInfoWithAlertingMode = UsersInfoProvider.shared.getUsersInfo(selectedMode: .alerting)
            
            guard let self = self, usersInfoWithAlertingMode.isEmpty == false else { return }
            
            let chatsIds: [Int64] = usersInfoWithAlertingMode.map { $0.chatId }
            self.alertAboutProfitability(earningSchemes: self.alertingSchemes, chatsIds: chatsIds, bot: bot)
            self.alertAboutArbitrage(opportunities: self.arbitragingOpportunities, chatsIds: chatsIds, bot: bot)
        }
    }
    
    func startLoggingJob(bot: TGBotPrtcl) {
        Jobs.add(interval: .seconds(Mode.logging.jobInterval)) { [weak self] in
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
    
    /// add handler for command "/start"
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
    
    /// add handler for command "/start_trading"
    func commandStartTradingHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [Mode.trading.command]) { [weak self] update, bot in
            guard let self = self, let chatId = update.message?.chat.id, let user = update.message?.from else { return }
            
            if UsersInfoProvider.shared.getUsersInfo(selectedMode: .trading).contains(where: { $0.chatId == chatId }) {
                let infoMessage = "Та все й так пашу. Можешь мене зупинить якшо не нравиться /stop"
                do {
                    _ = try bot.sendMessage(params: .init(chatId: .chat(chatId), text: infoMessage))
                } catch (let botError) {
                    self.logger.report(error: botError)
                }
            } else {
                let infoMessage = "Тепер Ви будете бачете повідовлення, яке буде оновлюватися акутальними розцінками кожні \(Int(Mode.trading.jobInterval)) секунд у наступному форматі:\n\(self.resultsFormatDescription)"
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
    
    /// add handler for command "/start_alerting"
    func commandStartAlertingHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [Mode.alerting.command]) { [weak self] update, bot in
            guard let self = self, let chatId = update.message?.chat.id, let user = update.message?.from else { return }
            
            do {
                if UsersInfoProvider.shared.getUsersInfo(selectedMode: .alerting).contains(where: { $0.chatId == chatId }) {
                    _ = try bot.sendMessage(params: .init(chatId: .chat(chatId), text: "Та все й так пашу. Можешь мене зупинить якшо не нравиться /stop"))
                } else {
                    let schemesFullDescription = self.alertingSchemes
                        .map { "\($0.shortDescription) >= \($0.valuableProfit) %" }
                        .joined(separator: "\n")
                    let opportunitiesFullDescription = self.arbitragingOpportunities
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
    
    /// add handler for command "/start_logging"
    func commandStartLoggingHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [Mode.logging.command]) { [weak self] update, bot in
            guard let self = self, let chatId = update.message?.chat.id, let user = update.message?.from else { return }
            
            if UsersInfoProvider.shared.getUsersInfo(selectedMode: .logging).contains(where: { $0.chatId == chatId }) {
                let infoMessage = "Та все й так пашу. Можешь мене зупинить якшо не нравиться /stop"
                do {
                    _ = try bot.sendMessage(params: .init(chatId: .chat(chatId), text: infoMessage))
                } catch (let botError) {
                    self.logger.report(error: botError)
                }
            } else {
                let infoMessage = "Тепер я буду кожні \(Int(Mode.logging.jobInterval / 60.0)) хвалин відправляти тобі статус всіх торгових можливостей у форматі\n\(self.resultsFormatDescription)"
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
    
    /// add handler for command "/stop"
    func commandStopHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [Mode.suspended.command]) { update, bot in
            guard let chatId = update.message?.chat.id else { return }
            
            UsersInfoProvider.shared.handleStopAllModes(chatId: chatId)
            _ = try? bot.sendMessage(params: .init(chatId: .chat(chatId), text: "Ну і ладно, я всьо равно вже заморився.."))// "Now bot will have some rest.."))
        }
        bot.connection.dispatcher.add(handler)
    }
    
    /// add handler for command "/test"
    func commandTestHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: ["/test"]) { [weak self] update, bot in
            guard let self = self, let chatId = update.message?.chat.id else { return }
           
            let usersDescription = UsersInfoProvider.shared.getAllUsersInfo()
                .map { $0.description }
                .joined(separator: "\n")
            
            var arbitragingPricesInfodescription = ""
            self.getOpportunitiesResults(for: self.arbitragingOpportunities) { opportunitiesResults in
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
                    crypto: binanceP2POpportunity.crypto.apiDescription
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
            EXMOAPIService.shared.getOrderbook(paymentMethod: exmoOpportunity.paymentMethod.apiDescription) { [weak self] askTop, bidTop, error in
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
            CoinsbitAPIService.shared.getTicker(market: coinsbitOpportunity.paymentMethod.apiDescription, completion: { [weak self] ask, bid, error in
                guard let possibleSellPrice = bid, let possibleBuyPrice = ask else {
                    self?.logger.info(Logger.Message(stringLiteral: "NO PRICES FOR COINSBIT"))
                    completion(nil)
                    return
                }
                completion(PricesInfo(possibleSellPrice: possibleSellPrice, possibleBuyPrice: possibleBuyPrice))
            })
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
    
    func alertAboutArbitrage(opportunities: [Opportunity], chatsIds: [Int64], bot: TGBotPrtcl) {
        getOpportunitiesResults(for: opportunities) { [weak self] opportunitiesResults in
            let biggestSellFinalPriceOpportunityResult = opportunitiesResults
                .filter { $0.finalSellPrice != nil }
                .sorted { $0.finalSellPrice ?? 0.0 > $1.finalSellPrice ?? 0.0 }
                .first
            
            let lowestBuyFinalPriceOpportunityResult = opportunitiesResults
                .filter { $0.finalBuyPrice != nil }
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
            let valuableProfitPercent: Double = 1 // %
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
        return SpreadInfo(dirtySpread, cleanSpread)
    }
    
}
