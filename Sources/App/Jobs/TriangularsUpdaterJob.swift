//
//  TriangularsUpdaterJob.swift
//  
//
//  Created by Ruslan on 28.12.2022.
//

import Queues
import Vapor
import CoreFoundation

struct TriangularsUpdaterJob: ScheduledJob {
    
    private let app: Application
    private let emailService: EmailService
    private let stockExchange: StockExchange
    
    init(app: Application, stockEchange: StockExchange) {
        self.app = app
        self.emailService = EmailService(app: app)
        self.stockExchange = stockEchange
    }
    
    func run(context: Queues.QueueContext) -> NIOCore.EventLoopFuture<Void> {
        return context.eventLoop.performWithTask {
            do {
                let tradeableSymbols: [TradeableSymbol]
                
                switch stockExchange {
                case .binance:
                    let binanceTradeableSymbols = try await BinanceAPIService().getExchangeInfo()
                        .filter { $0.status == .trading && $0.isSpotTradingAllowed }
                        .filter { $0.baseAsset != "RUB" && $0.quoteAsset != "RUB" }
                    
                    tradeableSymbols = binanceTradeableSymbols
                    let binanceTradeableSymbolsDict: [String: BinanceAPIService.Symbol] = binanceTradeableSymbols.toDictionary(with: { $0.symbol })
                    try await app.caches.memory.set(Constants.Binance.tradeableSymbolsDictKey, to: binanceTradeableSymbolsDict)
                    let tradeableSymbolsEndcodedData = try JSONEncoder().encode(binanceTradeableSymbolsDict)
                    try tradeableSymbolsEndcodedData.write(to: Constants.Binance.tradeableDictURL)
                case .bybit:
                    tradeableSymbols = try await ByBitAPIService().getSymbols()
                        .filter { $0.status == "Trading" }
                case .huobi:
                    tradeableSymbols = try await HuobiAPIService.shared
                        .getSymbolsInfo()
                        .filter { $0.state == .online }
                case .exmo:
                    tradeableSymbols = try await ExmoAPIService.shared.getSymbols()
                case .kucoin:
                    tradeableSymbols = try await KuCoinAPIService.shared
                        .getSymbols()
                        .filter { $0.enableTrading }
                case .kraken:
                    tradeableSymbols = try await KrakenAPIService.shared
                        .getSymbols()
                        .filter { $0.status == .online }
                case .whitebit:
                    tradeableSymbols = try await WhiteBitAPIService.shared.getSymbols()
                case .gateio:
                    tradeableSymbols = try await GateIOAPIService.shared
                        .getSymbols()
                        .filter { $0.tradeStatus == .tradable }
                }
                
                let standartTriangulars = TriangularsCalculator.getTriangularsInfo(for: .standart, from: tradeableSymbols)
                let standartTriangularsEndcodedData = try JSONEncoder().encode(standartTriangulars)
                try standartTriangularsEndcodedData.write(to: stockExchange.standartTriangularsStorageURL)
                
                let stableTriangulars = TriangularsCalculator.getTriangularsInfo(for: .stable, from: tradeableSymbols)
                let stableTriangularsEndcodedData = try JSONEncoder().encode(stableTriangulars)
                try stableTriangularsEndcodedData.write(to: stockExchange.stableTriangularsStorageURL)
            } catch {
                print(error.localizedDescription)
                emailService.sendEmail(
                    subject: "[\(stockExchange)] [triangulars]",
                    text: error.localizedDescription
                )
            }
        }
    }
    
}
