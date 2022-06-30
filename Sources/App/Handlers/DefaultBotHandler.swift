//
//  DefaultBotHandler.swift
//  
//
//  Created by Ruslan Popesku on 22.06.2022.
//

import Vapor
import telegram_vapor_bot
import Jobs

final class DefaultBotHandlers {
    
    typealias PricesInfo = (possibleSellPrice: Double, possibleBuyPrice: Double)
    
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
            case .trading: return 30
            case .alerting: return 300
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
    
    private let resultsFormatDescription = "crypto(payment method) sell - buy | possible price Sell - Buy | spread Mad - Clean | Clean Profit in %"
    
    
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
                    self?.printP2P(opportunities: EarningScheme.allCases,
                                   bot: bot,
                                   update: update)
                }
            }
        }
        bot.connection.dispatcher.add(handler)
    }
    
    /// add handler for command "/start_trading"
    func commandStartTradingHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [Mode.trading.command]) { [weak self] update, bot in
            guard let self = self else { return }
            
            if self.tradingJob?.isRunning != nil {
                let infoMessage = "Trading Updates already running!"
                _ = try? bot.sendMessage(params: .init(chatId: .chat(update.message!.chat.id), text: infoMessage))
            } else {
                let infoMessage = "Now you will see market updates every \(Int(Mode.trading.jobInterval)) seconds \n\(self.resultsFormatDescription)"
                _ = try? bot.sendMessage(params: .init(chatId: .chat(update.message!.chat.id), text: infoMessage))
                
                self.tradingJob = Jobs.add(interval: .seconds(Mode.trading.jobInterval)) { [weak self] in
                    let tradingOpportunities: [EarningScheme] = [
                        .monobankUSDT_monobankUSDT,
                        .privatbankUSDT_privabbankUSDT,
                        .abankUSDT_monobankUSDT,
                        .pumbUSDT_monobankUSDT,
                        .monobankBUSD_monobankUSDT,
                        .privatbankBUSD_privatbankUSDT
                    ]
                    self?.printP2P(opportunities: tradingOpportunities,
                                   bot: bot,
                                   update: update)
                }
            }
        }
        bot.connection.dispatcher.add(handler)
    }
    
    /// add handler for command "/start_alerting"
    func commandStartAlertingHandler(app: Vapor.Application, bot: TGBotPrtcl) {
        let handler = TGCommandHandler(commands: [Mode.alerting.command]) { [weak self] update, bot in
            guard let self = self else { return }
            
            let profitableSpread = 0.3
            let extraOpportunities = """
            Binance - Mono - WhiteBit - Binance  (with spread >= \(profitableSpread.toLocalCurrency()))
            Binance - WhiteBit - MonoBank(Any Bank) - Binance  (with spread >= \(profitableSpread.toLocalCurrency()))
            """
            
            if self.alertingJob?.isRunning != nil {
                _ = try? bot.sendMessage(params: .init(chatId: .chat(update.message!.chat.id),
                                                       text: "Already handling Extra opportinuties:\n\(extraOpportunities)"))
            } else {
                _ = try? bot.sendMessage(params: .init(chatId: .chat(update.message!.chat.id),
                                                       text: "Started handling Extra opportinuties:\n\(extraOpportunities)"))
                self.alertingJob = Jobs.add(interval: .seconds(Mode.alerting.jobInterval)) { [weak self] in
                    self?.checkWhiteBitArbitrage(profitableSpread: profitableSpread, bot: bot, update: update)
                    self?.checkHuobiArbitrage(profitableSpread: profitableSpread, bot: bot, update: update)
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
    
    func printP2P(opportunities: [EarningScheme], bot: TGBotPrtcl, update: TGUpdate) {
        let opportunitiesGroup = DispatchGroup()
        var totalDescriptioon: String = ""
        
        opportunities.forEach { opportunity in
            opportunitiesGroup.enter()
            getSpreadDescription(for: opportunity) { description in
                totalDescriptioon.append("\(description)")
                opportunitiesGroup.leave()
            }
        }
        
        opportunitiesGroup.notify(queue: .global()) {
            let params: TGSendMessageParams = .init(chatId: .chat(update.message!.chat.id), text: totalDescriptioon)
            _ = try? bot.sendMessage(params: params)
        }
    }
    
    func getSpreadDescription(for earningScheme: EarningScheme, completion: @escaping(String) -> Void) {
        getPricesInfo(for: earningScheme) { pricesInfo in
            guard let pricesInfo = pricesInfo else {
                completion("No PricesInfo for \(earningScheme)")
                return
            }
            
            let dirtySpread = pricesInfo.possibleSellPrice - pricesInfo.possibleBuyPrice
            let cleanSpread = dirtySpread - pricesInfo.possibleSellPrice * 0.001 * 2 // 0.1 % Binance Commission
            let cleanSpreadPercentString = (cleanSpread / pricesInfo.possibleSellPrice * 100).toLocalCurrency()
            
            let message = ("\(earningScheme.description) | \(pricesInfo.possibleSellPrice.toLocalCurrency()) - \(pricesInfo.possibleBuyPrice.toLocalCurrency()) | \(dirtySpread.toLocalCurrency()) - \(cleanSpread.toLocalCurrency()) | \(cleanSpreadPercentString)%\n")
            completion(message)
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
        case .huobi:
            HuobiAPIService.shared.getOrderbook { asks, bids, error in
                completion(PricesInfo(possibleSellPrice: bids.first ?? 0, possibleBuyPrice: asks.first ?? 0))
            }
        }
        
    }
    
}

// MARK: - ARBITRAGE

private extension DefaultBotHandlers {
    
    func checkWhiteBitArbitrage(profitableSpread: Double, bot: TGBotPrtcl, update: TGUpdate) {
        var whiteBitAsks: [Double]?
        var whiteBitBids: [Double]?
        var monoPricesInfo: PricesInfo? = nil
        let arbitrageGroup = DispatchGroup()
        
        arbitrageGroup.enter()
        getPricesInfo(for: EarningScheme.monobankUSDT_monobankUSDT) { pricesInfo in
            monoPricesInfo = pricesInfo
            arbitrageGroup.leave()
        }
        arbitrageGroup.enter()
        WhiteBitAPIService.shared.getOrderbook(for: .usdtuah) { asks, bids, error in
            whiteBitAsks = asks
            whiteBitBids = bids
            arbitrageGroup.leave()
        }
        
        arbitrageGroup.notify(queue: .global()) {
            guard let whiteBitBuy = whiteBitAsks?.first,
                  let whiteBitSell = whiteBitBids?.first,
                  let monoPricesInfo = monoPricesInfo else {
                return
            }

            if monoPricesInfo.possibleSellPrice - whiteBitBuy > profitableSpread {
                // If prices for Buying on WhiteBit is Much more lower then prices for selling on Monobank
                let text = "OPPORTINITY!    Mono Sell: \(monoPricesInfo.possibleSellPrice.toLocalCurrency()) - WhiteBit buy: \(whiteBitBuy.toLocalCurrency()) = \((monoPricesInfo.possibleSellPrice - whiteBitBuy).toLocalCurrency())"
                _ = try? bot.sendMessage(params: .init(chatId: .chat(update.message!.chat.id), text: text))
            } else if whiteBitSell - monoPricesInfo.possibleBuyPrice > profitableSpread {
                // If prices for Selling on White bit much more lower then prices for buying on Monobank
                let text = "OPPORTINITY!    WhiteBit sell: \(whiteBitSell.toLocalCurrency()) - Mono Buy: \(monoPricesInfo.possibleBuyPrice.toLocalCurrency()) = \((whiteBitSell - monoPricesInfo.possibleBuyPrice).toLocalCurrency())"
                _ = try? bot.sendMessage(params: .init(chatId: .chat(update.message!.chat.id), text: text))
            }
        }
    }
    
    func checkHuobiArbitrage(profitableSpread: Double, bot: TGBotPrtcl, update: TGUpdate) {
        var huobiAsks: [Double]?
        var huobiBids: [Double]?
        var monoPricesInfo: PricesInfo? = nil
        let arbitrageGroup = DispatchGroup()

        arbitrageGroup.enter()
        getPricesInfo(for: EarningScheme.monobankUSDT_monobankUSDT) { pricesInfo in
            monoPricesInfo = pricesInfo
            arbitrageGroup.leave()
        }
        arbitrageGroup.enter()
        HuobiAPIService.shared.getOrderbook { asks, bids, error in
            huobiAsks = asks
            huobiBids = bids
            arbitrageGroup.leave()
        }
        
        arbitrageGroup.notify(queue: .global()) {
            guard let huobiBuy = huobiAsks?.first,
                  let huobiSell = huobiBids?.first,
                  let monoPricesInfo = monoPricesInfo else {
                return
            }

            if monoPricesInfo.possibleSellPrice - huobiBuy > profitableSpread {
                // If prices for Buying on WhiteBit is Much more lower then prices for selling on Monobank
                let text = "OPPORTINITY!    Mono Sell: \(monoPricesInfo.possibleSellPrice.toLocalCurrency()) - Huobi buy: \(huobiBuy.toLocalCurrency()) = \((monoPricesInfo.possibleSellPrice - huobiBuy).toLocalCurrency())"
                _ = try? bot.sendMessage(params: .init(chatId: .chat(update.message!.chat.id), text: text))
            } else if huobiSell - monoPricesInfo.possibleBuyPrice > profitableSpread {
                // If prices for Selling on White bit much more lower then prices for buying on Monobank
                let text = "OPPORTINITY!    Huobi sell: \(huobiSell.toLocalCurrency()) - Mono Buy: \(monoPricesInfo.possibleBuyPrice.toLocalCurrency()) = \((huobiSell - monoPricesInfo.possibleBuyPrice).toLocalCurrency())"
                _ = try? bot.sendMessage(params: .init(chatId: .chat(update.message!.chat.id), text: text))
            }
        }
    }
    
}
