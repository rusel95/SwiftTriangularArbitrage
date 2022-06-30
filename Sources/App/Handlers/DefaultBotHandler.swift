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
    
    typealias PricesInfo = (possibleBuyPrice: Double, possibleSellPrice: Double)
    
    enum EarningScheme: CaseIterable {
        
        case monobankUSDT_monobankUSDT
        case privatbankUSDT_privabbankUSDT
        case abankUSDT_monobankUSDT
        case pumbUSDT_monobankUSDT
        case wiseUSDT_wiseUSDT
        case monobankBUSD_monobankUSDT
        case privatbankBUSD_privatbankUSDT
//        case binancePayUAH_binancePayUAH // + have to add Spot prices handling
        
        struct Opportunity {
            
            let crypto: Binance.Crypto
            let paymentMethod: Binance.PaymentMethod
            let numberOfAdvsToConsider: UInt8
            
            static let monobankUSDT = Opportunity(crypto: .usdt, paymentMethod: .monobank, numberOfAdvsToConsider: 10)
            static let monobankBUSD = Opportunity(crypto: .busd, paymentMethod: .monobank, numberOfAdvsToConsider: 3)
            static let privatbankUSDT = Opportunity(crypto: .usdt, paymentMethod: .privatbank, numberOfAdvsToConsider: 10)
            static let privatbankBUSD = Opportunity(crypto: .busd, paymentMethod: .privatbank, numberOfAdvsToConsider: 3)
            static let abankUSDT = Opportunity(crypto: .usdt, paymentMethod: .abank, numberOfAdvsToConsider: 3)
            static let pumbUSDT = Opportunity(crypto: .usdt, paymentMethod: .pumb, numberOfAdvsToConsider: 2)
            static let wiseUSDT = Opportunity(crypto: .usdt, paymentMethod: .wise, numberOfAdvsToConsider: 3)
//            static let binancePayUSDT = Opportunity(crypto: .usdt, paymentMethod: .binancePayUAH, numberOfAdvsToConsider: 2)
            
        }
        
        var sellOpportunity: Opportunity {
            switch self {
            case .monobankUSDT_monobankUSDT: return .monobankUSDT
            case .monobankBUSD_monobankUSDT: return .monobankBUSD
            case .privatbankUSDT_privabbankUSDT: return .privatbankUSDT
            case .privatbankBUSD_privatbankUSDT: return .privatbankBUSD
            case .abankUSDT_monobankUSDT: return .abankUSDT
            case .pumbUSDT_monobankUSDT: return .pumbUSDT
            case .wiseUSDT_wiseUSDT: return .wiseUSDT
//            case .binancePayUAH_binancePayUAH: return .binancePayUSDT
            }
        }
        
        var buyOpportunity: Opportunity {
            switch self {
            case .monobankUSDT_monobankUSDT, .monobankBUSD_monobankUSDT: return .monobankUSDT
            case .privatbankUSDT_privabbankUSDT, .privatbankBUSD_privatbankUSDT: return .privatbankUSDT
            case .abankUSDT_monobankUSDT, .pumbUSDT_monobankUSDT: return .monobankUSDT
            case .wiseUSDT_wiseUSDT: return .wiseUSDT
//            case .binancePayUAH_binancePayUAH: return .binancePayUSDT
            }
        }
        
        var description: String {
            let basicDescription = "\(sellOpportunity.crypto.rawValue)(\(sellOpportunity.paymentMethod.rawValue)) / \(buyOpportunity.crypto.rawValue) (\(buyOpportunity.paymentMethod.rawValue)) "
            var spacedMessage = basicDescription
            switch self {
            case .monobankUSDT_monobankUSDT, .monobankBUSD_monobankUSDT, .privatbankUSDT_privabbankUSDT, .privatbankBUSD_privatbankUSDT, .pumbUSDT_monobankUSDT: break
            case .abankUSDT_monobankUSDT: spacedMessage.append("        ")
            case .wiseUSDT_wiseUSDT: spacedMessage.append("                    ")
//            case .binancePayUAH_binancePayUAH: spacedMessage.append("")
            }
            return spacedMessage
        }
        
    }
    
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

// MARK: - Helpers
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
            
            let dirtySpread = pricesInfo.possibleBuyPrice - pricesInfo.possibleSellPrice
            let cleanSpread = dirtySpread - pricesInfo.possibleBuyPrice * 0.001 * 2 // 0.1 % Binance Commission
            let cleanSpreadPercentString = (cleanSpread / pricesInfo.possibleBuyPrice * 100).toLocalCurrency()
            
            let message = ("\(earningScheme.description) | \(pricesInfo.possibleBuyPrice.toLocalCurrency()) - \(pricesInfo.possibleSellPrice.toLocalCurrency()) | \(dirtySpread.toLocalCurrency()) - \(cleanSpread.toLocalCurrency()) | \(cleanSpreadPercentString)%\n")
            completion(message)
        }
    }
    
    func getPricesInfo(for earningScheme: EarningScheme, completion: @escaping(PricesInfo?) -> Void) {
        if earningScheme.buyOpportunity.paymentMethod == earningScheme.sellOpportunity.paymentMethod {
            BinanceAPIService.shared.loadAdvertisements(
                for: earningScheme.sellOpportunity.paymentMethod,
                crypto: earningScheme.sellOpportunity.crypto,
                numberOfAdvsToConsider: earningScheme.sellOpportunity.numberOfAdvsToConsider
            ) { buyAdvs, sellAdvs, error in
                guard let buyAdvs = buyAdvs, let sellAdvs = sellAdvs else {
                    completion(nil)
                    return
                }
                
                let buyPrices = buyAdvs
                    .filter { Double($0.surplusAmount) ?? 0 >= 200 }
                    .filter { Double($0.minSingleTransAmount) ?? 0 >= 2000 && Double($0.minSingleTransAmount) ?? 0 <= 100000 }
                    .compactMap { Double($0.price) }
                    .compactMap { $0 }
                
                let averageBuyPrice = buyPrices.reduce(0.0, +) / Double(buyPrices.count)
                
                let sellPrices = sellAdvs
                    .filter { Double($0.surplusAmount) ?? 0 >= 200 }
                    .filter { Double($0.minSingleTransAmount) ?? 0 >= 2000 && Double($0.minSingleTransAmount) ?? 0 <= 100000 }
                    .compactMap { Double($0.price) }
                    .compactMap { $0 }
                let averageSellPrice = sellPrices.reduce(0.0, +) / Double(sellPrices.count)
                completion(PricesInfo(possibleBuyPrice: averageBuyPrice, possibleSellPrice: averageSellPrice))
            }
        } else {
            var averageSellPrice: Double = 0
            var averageBuyPrice: Double = 0
            
            let priceInfoGroup = DispatchGroup()
            
            priceInfoGroup.enter()
            BinanceAPIService.shared.loadAdvertisements(
                for: earningScheme.sellOpportunity.paymentMethod,
                crypto: earningScheme.sellOpportunity.crypto,
                numberOfAdvsToConsider: earningScheme.sellOpportunity.numberOfAdvsToConsider
            ) { _, sellAdvs, _ in
                guard let sellAdvs = sellAdvs else {
                    priceInfoGroup.leave()
                    return
                }
                
                let sellPrices = sellAdvs
                    .filter { Double($0.surplusAmount) ?? 0 >= 200 }
                    .filter { Double($0.minSingleTransAmount) ?? 0 >= 2000 && Double($0.minSingleTransAmount) ?? 0 <= 100000 }
                    .compactMap { Double($0.price) }
                    .compactMap { $0 }
                averageSellPrice = sellPrices.reduce(0.0, +) / Double(sellPrices.count)
                priceInfoGroup.leave()
            }
            priceInfoGroup.enter()
            BinanceAPIService.shared.loadAdvertisements(
                for: earningScheme.buyOpportunity.paymentMethod,
                crypto: earningScheme.buyOpportunity.crypto,
                numberOfAdvsToConsider: earningScheme.buyOpportunity.numberOfAdvsToConsider
            ) { buyAdvs, _, _ in
                guard let buyAdvs = buyAdvs else {
                    priceInfoGroup.leave()
                    return
                }
                let buyPrices = buyAdvs
                    .filter { Double($0.surplusAmount) ?? 0 >= 200 }
                    .filter { Double($0.minSingleTransAmount) ?? 0 >= 2000 && Double($0.minSingleTransAmount) ?? 0 <= 100000 }
                    .compactMap { Double($0.price) }
                    .compactMap { $0 }
                
                averageBuyPrice = buyPrices.reduce(0.0, +) / Double(buyPrices.count)
                priceInfoGroup.leave()
            }
            
            priceInfoGroup.notify(queue: .global()) {
                completion(PricesInfo(possibleBuyPrice: averageBuyPrice, possibleSellPrice: averageSellPrice))
            }
        }
    }
    
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
                let text = "OPPORTINITY!    Mono Sell: \(monoPricesInfo.possibleBuyPrice.toLocalCurrency()) - WhiteBit buy: \(whiteBitBuy.toLocalCurrency()) = \((monoPricesInfo.possibleBuyPrice - whiteBitBuy).toLocalCurrency())"
                _ = try? bot.sendMessage(params: .init(chatId: .chat(update.message!.chat.id), text: text))
            } else if whiteBitSell - monoPricesInfo.possibleBuyPrice > profitableSpread {
                // If prices for Selling on White bit much more lower then prices for buying on Monobank
                let text = "OPPORTINITY!    WhiteBit sell: \(whiteBitSell.toLocalCurrency()) - Mono Buy: \(monoPricesInfo.possibleBuyPrice.toLocalCurrency()) = \((whiteBitSell - monoPricesInfo.possibleBuyPrice).toLocalCurrency())"
                _ = try? bot.sendMessage(params: .init(chatId: .chat(update.message!.chat.id), text: text))
            }
        }
    }
    
}
