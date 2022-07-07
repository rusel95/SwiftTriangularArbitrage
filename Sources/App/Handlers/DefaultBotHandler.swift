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

final class DefaultBotHandlers {
    
    // MARK: - ENUMERATIONS
    
    private enum Mode {
        
        case logging
        case trading
        case alerting /*
                       example 1: USDT/UAH spot -> UAH Crypto to UAH fiat -> UAH fiat to USDT
                       example 2: BTC(other coint)/USDT spot price >= 2% difference to p2p market
                       example 3: Stable Coin/Stable Coin price >= 3% difference then normal level
                       */
        case suspended
        
        var jobInterval: Double { // in seconds
            switch self {
            case .logging: return 900
            case .trading: return 10
            case .alerting: return 60
            case .suspended: return 0
            }
        }
        
        var command: String {
            switch self {
            case .trading: return "/start_trading"
            case .logging: return "/start_logging"
            case .alerting: return "/start_alerting"
            case .suspended: return "/stop"
            }
        }
    }
    
    // MARK: - PROPERTIES
    
    static let shared = DefaultBotHandlers()
    
    private var tradingJob: Job? = nil
    private var loggingJob: Job? = nil
    private var alertingJob: Job? = nil
    
    // Stores Last Alert Date for each scheme - needed to send Alert with some periodisation
    private var lastAlertingEvents: [EarningScheme: Date] = [:]
    
    private let resultsFormatDescription = "Крипто продажа(платіжний спосіб) - покупка(платіжний спосіб) | можлива ціна Продажі - Покупки | спред повний - чистий | чистий профіт у %" //"crypto Sell(payment method) - Buy(payment method) | possible price Sell - Buy | spread Dirty - Clean | Clean Profit in %\n" +
    
    init() {
        tradingJob = nil
        loggingJob = nil
        alertingJob = nil
    }
    
    // MARK: - METHODS
    
    func addHandlers(app: Vapor.Application, bot: TGBotPrtcl) {
        commandStartHandler(app: app, bot: bot)
        commandStartLoggingHandler(app: app, bot: bot)
        commandStartTradingHandler(app: app, bot: bot)
        commandStartAlertingHandler(app: app, bot: bot)
        commandStopHandler(app: app, bot: bot)
    }

}

// MARK: - HANDLERS

private extension DefaultBotHandlers {
    
    /// add handler for command "/start"
    func commandStartHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: ["/start"]) { update, bot in
            let infoMessage = """
            Привіт, мене звати Пантелеймон!
            
            Я Телеграм-Бот, зроблений для допомоги у торгівлі на Binance P2P та пошуку нових потенційних можливостей для торгівлі/арбітражу на інших платформах. Список готових режимів роботи (декілька режимів можуть працювати одночасно):
            /start_trading - режим моніторингу основних схем торгівлі в режимі реального часу (відкриваємо і торгуємо);
            /start_logging - режим логування всіх наявних можливостей с певною періодичність (треба для ретроспективного бачення особливостей ринку і його подальшого аналізу);
            /start_alerting - режим, завдяки якому я сповіщу тебе як тільки в якійсь зі схім торгівлі зявляється чудова дохідність (максимум одне повідомлення на одну схему за годину);
            /stop - зупинка всіх режимів (очікування);
            
            Сподіваюся бути тобі корисним..
            
            Поки мене ще роблять, я можу тупить. Якшо так - пишіть за допомогую або з пропозиціями до @rusel95 або @AnhelinaGrigoryeva
            
            P.S. Вибачте за мій суржик, і за те шо туплю..
            """
            _ = try? bot.sendMessage(params: .init(chatId: .chat(update.message!.chat.id), text: infoMessage))
        }
        bot.connection.dispatcher.add(handler)
    }
    
    /// add handler for command "/start_trading"
    func commandStartTradingHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [Mode.trading.command]) { [weak self] update, bot in
            guard let self = self else { return }
            
            if self.tradingJob?.isRunning != nil {
                let infoMessage = "Та все й так пашу. Можешь мене зупинить якшо не нравиться /stop"//"Trading Updates already running!"
                _ = try? bot.sendMessage(params: .init(chatId: .chat(update.message!.chat.id), text: infoMessage))
            } else {
                let infoMessage = "Тепер Ви будете бачете повідовлення, яке буде оновлюватися акутальними розцінками кожні \(Int(Mode.trading.jobInterval)) секунд у наступному форматі:\n\(self.resultsFormatDescription)"// "Now you will see market updates in Real Time (with update interval \(Int(Mode.trading.jobInterval)) seconds) \n\(self.resultsFormatDescription)"
                let explanationMessageFutute = try? bot.sendMessage(params: .init(chatId: .chat(update.message!.chat.id), text: infoMessage))
                explanationMessageFutute?.whenComplete({ _ in
                    let editMessageFuture = try? bot.sendMessage(params: .init(chatId: .chat(update.message!.chat.id), text: "Уже пашу.."))// "Wait a sec.."))
                    editMessageFuture?.whenComplete({ result in
                        let messageIdForEditing = try? result.get().messageId
                        self.tradingJob = Jobs.add(interval: .seconds(Mode.trading.jobInterval)) { [weak self] in
                            let tradingOpportunities: [EarningScheme] = [
                                .monobankUSDT_monobankUSDT,
                                .privatbankUSDT_privabbankUSDT,
                                .abankUSDT_monobankUSDT,
                                .pumbUSDT_monobankUSDT,
                                .monobankBUSD_monobankUSDT,
                                .privatbankBUSD_privatbankUSDT
                            ]
                            self?.printDescription(earningShemes: tradingOpportunities,
                                           editMessageId: messageIdForEditing,
                                           update: update,
                                           bot: bot)
                        }
                    })
                })
            }
        }
        bot.connection.dispatcher.add(handler)
    }
    
    /// add handler for command "/start_logging"
    func commandStartLoggingHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [Mode.logging.command]) { [weak self] update, bot in
            guard let self = self else { return }
            
            if self.loggingJob?.isRunning != nil {
                let infoMessage = "Та все й так пашу. Можешь мене зупинить якшо не нравиться /stop" //"Logging Updates already running!"
                _ = try? bot.sendMessage(params: .init(chatId: .chat(update.message!.chat.id), text: infoMessage))
            } else {
                let infoMessage = "Тепер я буду кожні \(Int(Mode.logging.jobInterval / 60)) хвалин відправляти тобі статус всіх торгових можливостей у форматі\n\(self.resultsFormatDescription)" //"Now you will see market updates every \(Int(Mode.logging.jobInterval / 60)) minutes\n\(self.resultsFormatDescription)"
                _ = try? bot.sendMessage(params: .init(chatId: .chat(update.message!.chat.id), text: infoMessage))
                self.loggingJob = Jobs.add(interval: .seconds(Mode.logging.jobInterval)) { [weak self] in
                    self?.printDescription(earningShemes: EarningScheme.allCases,
                                   update: update,
                                   bot: bot)
                }
            }
        }
        bot.connection.dispatcher.add(handler)
    }
    
    /// add handler for command "/start_alerting"
    func commandStartAlertingHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [Mode.alerting.command]) { [weak self] update, bot in
            guard let self = self else { return }
            
            if self.alertingJob?.isRunning != nil {
                _ = try? bot.sendMessage(params: .init(chatId: .chat(update.message!.chat.id), text: "Та все й так пашу. Можешь мене зупинить якшо не нравиться /stop")) // "Already handling Extra opportinuties.."))
            } else {
                let wellKnownSchemesForAlerting: [EarningScheme] = [
                    .monobankUSDT_monobankUSDT,
                    .privatbankUSDT_privabbankUSDT,
                    .monobankBUSD_monobankUSDT,
                    .privatbankBUSD_privatbankUSDT,
                    .abankUSDT_monobankUSDT,
                    .pumbUSDT_monobankUSDT,
                    .huobiUSDT_monobankUSDT,
                    .monobankUSDT_huobiUSDT,
                    .whiteBitUSDT_monobankUSDT,
                    .monobankUSDT_whiteBitUSDT
                ]
                let schemesFullDescription = wellKnownSchemesForAlerting
                    .map { "\($0.shortDescription) >= \($0.profitableSpread) UAH" }
                    .joined(separator: "\n\n")
                
                _ = try? bot.sendMessage(params: .init(
                    chatId: .chat(update.message!.chat.id),
                    text: "Полювання за НадКрутими можливостями розпочато! Як тільки, так сразу я тобі скажу. Слідкую за наступними схемами:\n\n\(schemesFullDescription)"// "Started handling Extra opportinuties (max 1 alert/hour/ooportinity) for Schemes:\n\(schemesFullDescription)"
                ))
                self.alertingJob = Jobs.add(interval: .seconds(Mode.alerting.jobInterval)) { [weak self] in
                    self?.alertAboutProfitability(earningSchemes: wellKnownSchemesForAlerting, bot: bot, update: update)
                }
            }
        }
        bot.connection.dispatcher.add(handler)
    }
    
    /// add handler for command "/stop"
    func commandStopHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [Mode.suspended.command]) { [weak self] update, bot in
            self?.loggingJob?.stop()
            self?.loggingJob = nil
            self?.tradingJob?.stop()
            self?.tradingJob = nil
            self?.alertingJob?.stop()
            self?.alertingJob = nil
            _ = try? bot.sendMessage(params: .init(chatId: .chat(update.message!.chat.id), text: "Ну і ладно, я всьо равно вже заморився.."))// "Now bot will have some rest.."))
        }
        bot.connection.dispatcher.add(handler)
    }
    
}

// MARK: - P2P

private extension DefaultBotHandlers {
    
    func printDescription(earningShemes: [EarningScheme], editMessageId: Int? = nil, update: TGUpdate, bot: TGBotPrtcl) {
        let earningShemesGroup = DispatchGroup()
        var potentialEarningResults: [(scheme: EarningScheme, description: String)] = []
        earningShemes.forEach { earningSheme in
            earningShemesGroup.enter()
            getSpreadDescription(for: earningSheme) { description in
                potentialEarningResults.append((earningSheme, description))
                earningShemesGroup.leave()
            }
        }
        
        earningShemesGroup.notify(queue: .global()) {
            let totalDescriptioon = potentialEarningResults
                .sorted { $0.scheme.rawValue < $1.scheme.rawValue }
                .map { $0.description }
                .joined(separator: "\n")
            if let editMessageId = editMessageId {
                let params: TGEditMessageTextParams = .init(chatId: .chat(update.message!.chat.id), messageId: editMessageId, inlineMessageId: nil, text: totalDescriptioon)
                _ = try? bot.editMessageText(params: params)
            } else {
                let params: TGSendMessageParams = .init(chatId: .chat(update.message!.chat.id), text: totalDescriptioon)
                _ = try? bot.sendMessage(params: params)
            }
        }
    }
    
    func getSpreadDescription(for earningScheme: EarningScheme, completion: @escaping(String) -> Void) {
        getPricesInfo(for: earningScheme) { pricesInfo in
            guard let pricesInfo = pricesInfo else {
                completion("No PricesInfo for \(earningScheme)")
                return
            }
            
            completion(earningScheme.getPrettyDescription(with: pricesInfo))
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
        case .binance(let binance):
            BinanceAPIService.shared.loadAdvertisements(paymentMethod: binance.paymentMethod.apiDescription, crypto: binance.crypto.apiDescription) { [weak self] buyAdvs, sellAdvs, error in
                guard let self = self, let buyAdvs = buyAdvs, let sellAdvs = sellAdvs else {
                    completion(nil)
                    return
                }
                
                let makersBuyPrices = self.getFilteredPrices(advs: sellAdvs, binanceOpportunity: binance)
                let averagePossibleBuyPrice = makersBuyPrices.reduce(0.0, +) / Double(makersBuyPrices.count)
                
                let makersSellPrices = self.getFilteredPrices(advs: buyAdvs, binanceOpportunity: binance)
                let averagePossibleSellPrice = makersSellPrices.reduce(0.0, +) / Double(makersSellPrices.count)
                
                completion(PricesInfo(possibleSellPrice: averagePossibleSellPrice, possibleBuyPrice: averagePossibleBuyPrice))
            }
        case .whiteBit(let opportunity):
            WhiteBitAPIService.shared.getOrderbook(paymentMethod: opportunity.paymentMethod.apiDescription) { asks, bids, error in
                completion(PricesInfo(possibleSellPrice: bids?.first ?? 0, possibleBuyPrice: asks?.first ?? 0))
            }
        case .huobi(let opportunity):
            HuobiAPIService.shared.getOrderbook(paymentMethod: opportunity.paymentMethod.apiDescription) { asks, bids, error in
                completion(PricesInfo(possibleSellPrice: bids.first ?? 0, possibleBuyPrice: asks.first ?? 0))
            }
        }
        
    }
    
    func getFilteredPrices(advs: [Adv], binanceOpportunity: Opportunity.Binance) -> [Double] {
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
    
    func alertAboutProfitability(earningSchemes: [EarningScheme], bot: TGBotPrtcl, update: TGUpdate) {
        earningSchemes.forEach { earningScheme in
            guard (Date() - (self.lastAlertingEvents[earningScheme] ?? Date())).seconds.unixTime > Duration.hours(1).unixTime ||
                self.lastAlertingEvents[earningScheme] == nil
            else { return }
            
            getPricesInfo(for: earningScheme) { pricesInfo in
                guard let pricesInfo = pricesInfo, earningScheme.getSpreads(for: pricesInfo).cleanSpread > earningScheme.profitableSpread  else { return }
                
                self.lastAlertingEvents[earningScheme] = Date()
                let text = "Profitable Opportunity!!! \(earningScheme.getPrettyDescription(with: pricesInfo))"
                _ = try? bot.sendMessage(params: .init(chatId: .chat(update.message!.chat.id), text: text))
            }
        }
    }
    
}
