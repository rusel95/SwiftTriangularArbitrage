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
            case .logging: return "/start_logging"
            case .trading: return "/start_trading"
            case .alerting: return "/start_alerting"
            case .suspended: return "/stop"
            }
        }
    }
    
    // MARK: - PROPERTIES
    
    static let shared = DefaultBotHandlers()
    
    private var loggingJob: Job?
    private var tradingJob: Job?
    private var alertingJob: Job?
    
    private let resultsFormatDescription = "Sell crypto(payment method) - Buy crypto(payment method) | possible price Sell - Buy | spread Dirty - Clean | Clean Profit in %"
    
    
    // MARK: - METHODS
    
    func addHandlers(app: Vapor.Application, bot: TGBotPrtcl) {
        commandStartLoggingHandler(app: app, bot: bot)
        commandStartTradingHandler(app: app, bot: bot)
        commandStartAlertingHandler(app: app, bot: bot)
        commandStopHandler(app: app, bot: bot)
    }

}

// MARK: - HELPERS

private extension DefaultBotHandlers {
    
    /// add handler for command "/start_trading"
    func commandStartTradingHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [Mode.trading.command]) { [weak self] update, bot in
            guard let self = self else { return }
            
            if self.tradingJob?.isRunning != nil {
                let infoMessage = "Trading Updates already running!"
                _ = try? bot.sendMessage(params: .init(chatId: .chat(update.message!.chat.id), text: infoMessage))
            } else {
                let infoMessage = "Now you will see market updates in Real Time (with update interval \(Int(Mode.trading.jobInterval)) seconds) \n\(self.resultsFormatDescription)"
                let explanationMessageFutute = try? bot.sendMessage(params: .init(chatId: .chat(update.message!.chat.id), text: infoMessage))
                explanationMessageFutute?.whenComplete({ _ in
                    let editMessageFuture = try? bot.sendMessage(params: .init(chatId: .chat(update.message!.chat.id), text: "Wait a sec.."))
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
                let infoMessage = "Logging Updates already running!"
                _ = try? bot.sendMessage(params: .init(chatId: .chat(update.message!.chat.id), text: infoMessage))
            } else {
                let infoMessage = "Now you will see market updates every \(Int(Mode.logging.jobInterval / 60)) minutes\n\(self.resultsFormatDescription)"
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
                _ = try? bot.sendMessage(params: .init(chatId: .chat(update.message!.chat.id), text: "Already handling Extra opportinuties.."))
            } else {
                let schemesForAlerting = EarningScheme.allCases
                let schemesFullDescription = schemesForAlerting.map { "\($0.shortDescription) >= \($0.profitableSpread) UAH" }.joined(separator: "\n")
                _ = try? bot.sendMessage(params: .init(
                    chatId: .chat(update.message!.chat.id),
                    text: "Started handling Extra opportinuties for Schemes:\n\(schemesFullDescription)"
                ))
                self.alertingJob = Jobs.add(interval: .seconds(Mode.alerting.jobInterval)) { [weak self] in
                    self?.alertAboutProfitability(earningSchemes: schemesForAlerting, bot: bot, update: update)
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
            _ = try? bot.sendMessage(params: .init(chatId: .chat(update.message!.chat.id), text: "Now bot will have some rest.."))
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
            BinanceAPIService.shared.loadAdvertisements(
                paymentMethod: binance.paymentMethod.apiDescription,
                crypto: binance.crypto.apiDescription,
                numberOfAdvsToConsider: binance.numberOfAdvsToConsider
            ) { buyAdvs, sellAdvs, error in
                guard let buyAdvs = buyAdvs, let sellAdvs = sellAdvs else {
                    completion(nil)
                    return
                }
                
                let makersBuyPrices = sellAdvs
                    .filter { Double($0.surplusAmount) ?? 0 >= 200 }
                    .filter { Double($0.minSingleTransAmount) ?? 0 >= 2000 && Double($0.minSingleTransAmount) ?? 0 <= 100000 }
                    .compactMap { Double($0.price) }
                    .compactMap { $0 }
                
                let averagePossibleBuyPrice = makersBuyPrices.reduce(0.0, +) / Double(makersBuyPrices.count)
                
                let makersSellPrices = buyAdvs
                    .filter { Double($0.surplusAmount) ?? 0 >= 200 }
                    .filter { Double($0.minSingleTransAmount) ?? 0 >= 2000 && Double($0.minSingleTransAmount) ?? 0 <= 100000 }
                    .compactMap { Double($0.price) }
                    .compactMap { $0 }
                let averagePossibleSellPrice = makersSellPrices.reduce(0.0, +) / Double(makersSellPrices.count)
                completion(PricesInfo(possibleSellPrice: averagePossibleSellPrice,
                                      possibleBuyPrice: averagePossibleBuyPrice))
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
    
}

// MARK: - ARBITRAGE

private extension DefaultBotHandlers {
    
    func alertAboutProfitability(earningSchemes: [EarningScheme], bot: TGBotPrtcl, update: TGUpdate) {
        earningSchemes.forEach { earningScheme in
            getPricesInfo(for: earningScheme) { pricesInfo in
                guard let pricesInfo = pricesInfo else { return }
                
                if earningScheme.getSpreads(for: pricesInfo).cleanSpread > earningScheme.profitableSpread {
                    let text = "Profitable Opportunity!!! \(earningScheme.getPrettyDescription(with: pricesInfo))"
                    _ = try? bot.sendMessage(params: .init(chatId: .chat(update.message!.chat.id), text: text))
                }
            }
        }
    }
    
}
