//
//  DefaultBotHandler.swift
//  
//
//  Created by Ruslan Popesku on 22.06.2022.
//

import Vapor
import telegram_vapor_bot
import Jobs

typealias PricesInfo = (possibleSellPrice: Double, possibleBuyPrice: Double)
typealias SpreadInfo = (dirtySpread: Double, cleanSpread: Double)

struct ChatInfo: Hashable {
    
    let chatId: Int64
    let editMessageId: Int?
    
}

final class DefaultBotHandlers {
    
    // MARK: - PROPERTIES
    
    static let shared = DefaultBotHandlers()
    
    private var tradingJob: Job?
    private var loggingJob: Job?
    private var alertingJob: Job?
    
    // Stores Last Alert Date for each scheme - needed to send Alert with some periodisation
    private var lastAlertingEvents: [String: Date] = [:]
    
    private let resultsFormatDescription = "Крипто продажа(платіжний спосіб) - покупка(платіжний спосіб) | можлива ціна Продажі - Покупки | спред повний - чистий | чистий профіт у %" //"crypto Sell(payment method) - Buy(payment method) | possible price Sell - Buy | spread Dirty - Clean | Clean Profit in %\n" +
    private let commandsDescription = """
        /start_trading - режим моніторингу основних схем торгівлі в режимі реального часу (відкриваємо і торгуємо);
        /start_logging - режим логування всіх наявних можливостей с певною періодичність (треба для ретроспективного бачення особливостей ринку і його подальшого аналізу);
        /start_alerting - режим, завдяки якому я сповіщу тебе як тільки в якійсь зі схім торгівлі зявляється чудова дохідність (максимум одне повідомлення на одну схему за годину);
        /stop - зупинка всіх режимів (очікування);
        """
    private let wellKnownSchemesForAlerting: [EarningScheme] = [
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
    private let opportunitiesForArbitrage: [Opportunity] = [
        .binance(.p2p(.monobankUSDT)),
        .huobi(.usdtSpot),
        .whiteBit(.usdtSpot),
        .binance(.spot(.usdtUAH)),
        .exmo(.usdtUAHSpot),
        .kuna(.usdtUAHSpot)
    ]
    
    // MARK: - METHODS
    
    func addHandlers(app: Vapor.Application, bot: TGBotPrtcl) {
        commandStartHandler(app: app, bot: bot)
        commandStartLoggingHandler(app: app, bot: bot)
        commandStartTradingHandler(app: app, bot: bot)
        commandStartAlertingHandler(app: app, bot: bot)
        commandStopHandler(app: app, bot: bot)
        commandTestHandler(app: app, bot: bot)
        
        startTradingJob(bot: bot)
        startLoggingJob(bot: bot)
        startAlertingJob(bot: bot)
    }
    
    func startTradingJob(bot: TGBotPrtcl) {
        tradingJob = Jobs.add(interval: .seconds(Mode.trading.jobInterval)) { [weak self] in
            let usersInfoWithTradingMode = UsersInfoProvider.shared.getUsersInfo(selectedMode: .trading)
            
            guard let self = self, usersInfoWithTradingMode.isEmpty == false else { return }
           
            let tradingOpportunities: [EarningScheme] = [
                .monobankUSDT_monobankUSDT,
                .privatbankUSDT_privabbankUSDT,
                .monobankBUSD_monobankUSDT,
                .privatbankBUSD_privatbankUSDT,
                .wiseUSDT_wiseUSDT
            ]
            let chatsInfo: [ChatInfo] = usersInfoWithTradingMode
                .map { ChatInfo(chatId: $0.chatId, editMessageId: $0.onlineUpdatesMessageId) }
            self.printDescription(earningSchemes: tradingOpportunities, chatsInfo: chatsInfo, bot: bot)
        }
    }
    
    func startLoggingJob(bot: TGBotPrtcl) {
        loggingJob = Jobs.add(interval: .seconds(Mode.logging.jobInterval)) { [weak self] in
            let usersInfoWithLoggingMode = UsersInfoProvider.shared.getUsersInfo(selectedMode: .logging)
            
            guard let self = self, usersInfoWithLoggingMode.isEmpty == false else { return }
            
            let chatsInfo: [ChatInfo] = usersInfoWithLoggingMode.map { ChatInfo(chatId: $0.chatId, editMessageId: nil) }
            self.printDescription(earningSchemes: EarningScheme.allCases, chatsInfo: chatsInfo, bot: bot)
        }
    }
    
    func startAlertingJob(bot: TGBotPrtcl) {
        alertingJob = Jobs.add(interval: .seconds(Mode.alerting.jobInterval)) { [weak self] in
            let usersInfoWithAlertingMode = UsersInfoProvider.shared.getUsersInfo(selectedMode: .alerting)
            
            guard let self = self, usersInfoWithAlertingMode.isEmpty == false else { return }
            
            let chatsInfo: [ChatInfo] = usersInfoWithAlertingMode.map { ChatInfo(chatId: $0.chatId, editMessageId: nil) }
            self.alertAboutProfitability(earningSchemes: self.wellKnownSchemesForAlerting, chatsInfo: chatsInfo, bot: bot)
            self.alertAboutArbitrage(opportunities: self.opportunitiesForArbitrage, chatsInfo: chatsInfo, bot: bot)
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
                let infoMessage = "Та все й так пашу. Можешь мене зупинить якшо не нравиться /stop"//"Trading Updates already running!"
                _ = try? bot.sendMessage(params: .init(chatId: .chat(chatId), text: infoMessage))
            } else {
                let infoMessage = "Тепер Ви будете бачете повідовлення, яке буде оновлюватися акутальними розцінками кожні \(Int(Mode.trading.jobInterval)) секунд у наступному форматі:\n\(self.resultsFormatDescription)"// "Now you will see market updates in Real Time (with update interval \(Int(Mode.trading.jobInterval)) seconds) \n\(self.resultsFormatDescription)"
                let explanationMessageFutute = try? bot.sendMessage(params: .init(chatId: .chat(chatId), text: infoMessage))
                explanationMessageFutute?.whenComplete({ _ in
                    let editMessageFuture = try? bot.sendMessage(params: .init(chatId: .chat(chatId), text: "Оновлюю.."))// "Wait a sec.."))
                    editMessageFuture?.whenComplete({ result in
                        let onlineUpdatesMessageId = try? result.get().messageId
                        UsersInfoProvider.shared.handleModeSelected(
                            chatId: chatId,
                            user: user,
                            mode: .trading,
                            onlineUpdatesMessageId: onlineUpdatesMessageId
                        )
                    })
                })
            }
        }
        bot.connection.dispatcher.add(handler)
    }
    
    /// add handler for command "/start_logging"
    func commandStartLoggingHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [Mode.logging.command]) { [weak self] update, bot in
            guard let self = self, let chatId = update.message?.chat.id, let user = update.message?.from else { return }
            
            if UsersInfoProvider.shared.getUsersInfo(selectedMode: .logging).contains(where: { $0.chatId == chatId }) {
                let infoMessage = "Та все й так пашу. Можешь мене зупинить якшо не нравиться /stop" //"Logging Updates already running!"
                _ = try? bot.sendMessage(params: .init(chatId: .chat(chatId), text: infoMessage))
            } else {
                let infoMessage = "Тепер я буду кожні \(Int(Mode.logging.jobInterval / 60)) хвалин відправляти тобі статус всіх торгових можливостей у форматі\n\(self.resultsFormatDescription)" //"Now you will see market updates every \(Int(Mode.logging.jobInterval / 60)) minutes\n\(self.resultsFormatDescription)"
                _ = try? bot.sendMessage(params: .init(chatId: .chat(chatId), text: infoMessage))
                UsersInfoProvider.shared.handleModeSelected(chatId: chatId, user: user, mode: .logging)
                self.printDescription(
                    earningSchemes: EarningScheme.allCases,
                    chatsInfo: [ChatInfo(chatId: chatId, editMessageId: nil)],
                    bot: bot
                )
            }
        }
        bot.connection.dispatcher.add(handler)
    }
    
    /// add handler for command "/start_alerting"
    func commandStartAlertingHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [Mode.alerting.command]) { [weak self] update, bot in
            guard let self = self, let chatId = update.message?.chat.id, let user = update.message?.from else { return }
            
            if UsersInfoProvider.shared.getUsersInfo(selectedMode: .alerting).contains(where: { $0.chatId == chatId }) {
                _ = try? bot.sendMessage(params: .init(chatId: .chat(chatId), text: "Та все й так пашу. Можешь мене зупинить якшо не нравиться /stop")) // "Already handling Extra opportinuties.."))
            } else {
                let schemesFullDescription = self.wellKnownSchemesForAlerting
                    .map { "\($0.shortDescription) >= \($0.valuableProfit) %" }
                    .joined(separator: "\n")
                let opportunitiesFullDescription = self.opportunitiesForArbitrage
                    .map { $0.description }
                    .joined(separator: "\n")
                
                let text = """
                Полювання за НадКрутими можливостями розпочато! Як тільки, так сразу я тобі скажу.
                
                Слідкую за наступними звязками:
                \(schemesFullDescription)
                
                Намагаюся знайти найращі можливості для Арбітражу для наступних можливостей покупки/продажі на:
                \(opportunitiesFullDescription)
                """// "Started handling Extra opportinuties (max 1 alert/hour/ooportinity) for Schemes:\n\(schemesFullDescription)"
                _ = try? bot.sendMessage(params: .init(chatId: .chat(chatId), text: text))
                UsersInfoProvider.shared.handleModeSelected(chatId: chatId, user: user, mode: .alerting)
            }
        }
        bot.connection.dispatcher.add(handler)
    }
    
    /// add handler for command "/stop"
    func commandStopHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [Mode.suspended.command]) { update, bot in
            guard let chatId = update.message?.chat.id else { return }
            
            UsersInfoProvider.shared.handleStopModes(chatId: chatId)
            _ = try? bot.sendMessage(params: .init(chatId: .chat(chatId), text: "Ну і ладно, я всьо равно вже заморився.."))// "Now bot will have some rest.."))
        }
        bot.connection.dispatcher.add(handler)
    }
    
    /// add handler for command "/test"
    func commandTestHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: ["/test"]) { update, bot in
            guard let chatId = update.message?.chat.id else { return }
           
            let testMessage = "some test message"
            _ = try? bot.sendMessage(params: .init(chatId: .chat(chatId), text: testMessage))
        }
        bot.connection.dispatcher.add(handler)
    }
    
}

// MARK: - HELPERS

private extension DefaultBotHandlers {
    
    func printDescription(earningSchemes: [EarningScheme], chatsInfo: [ChatInfo], bot: TGBotPrtcl) {
        let earningShemesGroup = DispatchGroup()
        var potentialEarningResults: [(scheme: EarningScheme, description: String)] = []
        earningSchemes.forEach { earningScheme in
            earningShemesGroup.enter()
            
            getPricesInfo(for: earningScheme) { pricesInfo in
                guard let pricesInfo = pricesInfo else {
                    potentialEarningResults.append((earningScheme, "No PricesInfo for \(earningScheme)"))
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
            let totalDescriptioon = potentialEarningResults
                .sorted { $0.scheme.rawValue < $1.scheme.rawValue }
                .map { $0.description }
                .joined(separator: "\n")
            chatsInfo.forEach { chatInfo in
                if let editMessageId = chatInfo.editMessageId {
                    let params: TGEditMessageTextParams = .init(chatId: .chat(chatInfo.chatId), messageId: editMessageId, inlineMessageId: nil, text: "\(totalDescriptioon)\nАктуально станом на \(Date().readableDescription)")
                    _ = try? bot.editMessageText(params: params)
                } else {
                    let params: TGSendMessageParams = .init(chatId: .chat(chatInfo.chatId), text: totalDescriptioon)
                    _ = try? bot.sendMessage(params: params)
                }
            }
           
        }
    }
    
    func getPricesInfo(for earningScheme: EarningScheme, completion: @escaping(PricesInfo?) -> Void) {
        if earningScheme.sellOpportunity == earningScheme.buyOpportunity {
            getPricesInfo(for: earningScheme.sellOpportunity) { pricesInfo in
                completion(pricesInfo)
            }
        } else {
            var averagePossibleSellPrice: Double = 0
            var averagePossibleBuyPrice: Double = 0

            let priceInfoGroup = DispatchGroup()
            priceInfoGroup.enter()
            getPricesInfo(for: earningScheme.sellOpportunity) { pricesInfo in
                averagePossibleSellPrice = pricesInfo?.possibleSellPrice ?? 0
                priceInfoGroup.leave()
            }
            
            priceInfoGroup.enter()
            getPricesInfo(for: earningScheme.buyOpportunity) { pricesInfo in
                averagePossibleBuyPrice = pricesInfo?.possibleBuyPrice ?? 0
                priceInfoGroup.leave()
            }
            priceInfoGroup.notify(queue: .global()) {
                completion(PricesInfo(possibleSellPrice: averagePossibleSellPrice,
                                      possibleBuyPrice: averagePossibleBuyPrice))
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
                BinanceAPIService.shared.getBookTicker(symbol: binanceSpotOpportunity.paymentMethod.rawValue) { ticker in
                    guard let possibleSellPrice = ticker?.sellPrice, let possibleBuyPrice = ticker?.buyPrice else {
                        completion(nil)
                        return
                    }
                    completion(PricesInfo(possibleSellPrice: possibleSellPrice, possibleBuyPrice: possibleBuyPrice))
                }
            }
           
        case .whiteBit(let opportunity):
            WhiteBitAPIService.shared.getOrderbook(paymentMethod: opportunity.paymentMethod.apiDescription) { asks, bids, error in
                guard let possibleSellPrice = bids?.first, let possibleBuyPrice = asks?.first else {
                    completion(nil)
                    return
                }
                completion(PricesInfo(possibleSellPrice: possibleSellPrice, possibleBuyPrice: possibleBuyPrice))
            }
                
        case .huobi(let opportunity):
            HuobiAPIService.shared.getOrderbook(paymentMethod: opportunity.paymentMethod.apiDescription) { asks, bids, error in
                guard let possibleSellPrice = bids.first, let possibleBuyPrice = asks.first else {
                    completion(nil)
                    return
                }
                completion(PricesInfo(possibleSellPrice: possibleSellPrice, possibleBuyPrice: possibleBuyPrice))
            }
        case .exmo(let exmoOpportunity):
            EXMOAPIService.shared.getOrderbook(paymentMethod: exmoOpportunity.paymentMethod.apiDescription) { askTop, bidTop, error in
                guard let possibleSellPrice = bidTop, let possibleBuyPrice = askTop else {
                    completion(nil)
                    return
                }
                completion(PricesInfo(possibleSellPrice: possibleSellPrice, possibleBuyPrice: possibleBuyPrice))
            }
        case .kuna(let kunaOpportunity):
            KunaAPIService.shared.getOrderbook(paymentMethod: kunaOpportunity.paymentMethod.apiDescription) { asks, bids, error in
                guard let possibleSellPrice = bids.first, let possibleBuyPrice = asks.first else {
                    completion(nil)
                    return
                }
                completion(PricesInfo(possibleSellPrice: possibleSellPrice, possibleBuyPrice: possibleBuyPrice))
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
    
    func alertAboutProfitability(earningSchemes: [EarningScheme], chatsInfo: [ChatInfo], bot: TGBotPrtcl) {
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
                
                chatsInfo.forEach { chatInfo in
                    _ = try? bot.sendMessage(params: .init(chatId: .chat(chatInfo.chatId), text: text))
                }
            }
        }
    }
    
    func alertAboutArbitrage(opportunities: [Opportunity], chatsInfo: [ChatInfo], bot: TGBotPrtcl) {
        let arbitrageGroup = DispatchGroup()
        var opportunitiesResults: [(opportunity: Opportunity, priceInfo: PricesInfo)] = []
        
        opportunities.forEach { opportunity in
            arbitrageGroup.enter()
            
            getPricesInfo(for: opportunity) { pricesInfo in
                guard let pricesInfo = pricesInfo else {
                    arbitrageGroup.leave()
                    return
                }
        
                opportunitiesResults.append((opportunity, pricesInfo))
                arbitrageGroup.leave()
            }
        }

        arbitrageGroup.notify(queue: .global()) { [weak self] in
            let biggestSellFinalPriceOpportunityResult = opportunitiesResults
                .filter { $0.opportunity.sellCommission != nil }
                .sorted {
                    let firstOpportunityFinalSellPrice = $0.priceInfo.possibleSellPrice - ($0.priceInfo.possibleSellPrice * ($0.opportunity.sellCommission ?? 0.0) / 100.0)
                    let secondOpportunityFinalSellPrice = $1.priceInfo.possibleSellPrice - ($1.priceInfo.possibleSellPrice * ($1.opportunity.sellCommission ?? 0.0) / 100.0)
                    return firstOpportunityFinalSellPrice > secondOpportunityFinalSellPrice
                }
                .first
            
            let lowestBuyFinalPriceOpportunityResult = opportunitiesResults
                .filter { $0.opportunity.buyCommission != nil }
                .sorted { (firstOpportinityResult, secondOpportunityResult) in
                    let firstOpportunityFinalBuyPrice = firstOpportinityResult.priceInfo.possibleBuyPrice + (firstOpportinityResult.priceInfo.possibleBuyPrice * (firstOpportinityResult.opportunity.buyCommission ?? 0.0) / 100.0)
                    let secondOpportunityFinalBuyPrice = secondOpportunityResult.priceInfo.possibleBuyPrice + (secondOpportunityResult.priceInfo.possibleBuyPrice * (secondOpportunityResult.opportunity.buyCommission ?? 0.0) / 100.0)
                    return firstOpportunityFinalBuyPrice < secondOpportunityFinalBuyPrice
                }
                .first
            
            guard let self = self,
                  let biggestSellFinalPriceOpportunityResult = biggestSellFinalPriceOpportunityResult,
                  let lowestBuyFinalPriceOpportunityResult = lowestBuyFinalPriceOpportunityResult
            else { return }
            
            let currentArbitragePossibilityID = "\(biggestSellFinalPriceOpportunityResult.opportunity.paymentMethodDescription)-\(lowestBuyFinalPriceOpportunityResult.opportunity.paymentMethodDescription)"
           
            let pricesInfo = PricesInfo(possibleSellPrice: biggestSellFinalPriceOpportunityResult.priceInfo.possibleSellPrice,
                                        possibleBuyPrice: lowestBuyFinalPriceOpportunityResult.priceInfo.possibleBuyPrice)
            
            let spreadInfo = self.getSpreadInfo(sellOpportunity: biggestSellFinalPriceOpportunityResult.opportunity,
                                                buyOpportunity: lowestBuyFinalPriceOpportunityResult.opportunity,
                                                pricesInfo: pricesInfo)
            let profitPercent: Double = (spreadInfo?.cleanSpread ?? 0.0 / pricesInfo.possibleSellPrice * 100.0)
            let valuableProfitPercent: Double = 1 // %
            guard ((Date() - (self.lastAlertingEvents[currentArbitragePossibilityID] ?? Date())).seconds.unixTime > Duration.hours(1).unixTime ||
                   self.lastAlertingEvents[currentArbitragePossibilityID] == nil) &&
                    profitPercent > valuableProfitPercent else { return } // %
            
            self.lastAlertingEvents[currentArbitragePossibilityID] = Date()
            let prettyDescription = self.getPrettyDescription(sellOpportunity: biggestSellFinalPriceOpportunityResult.opportunity,
                                                              buyOpportunity: lowestBuyFinalPriceOpportunityResult.opportunity,
                                                              pricesInfo: pricesInfo)
            chatsInfo.forEach { chatInfo in
                _ = try? bot.sendMessage(params: .init(chatId: .chat(chatInfo.chatId), text: "Арбітражна можливість: \(prettyDescription)"))
            }
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
