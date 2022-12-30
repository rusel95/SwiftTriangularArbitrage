//
//  TriangularsUpdaterJob.swift
//  
//
//  Created by Ruslan on 28.12.2022.
//

import Queues
import Vapor
import telegram_vapor_bot
import CoreFoundation

let binanceTradeableSymbolsDictKey = "binanceTradeableSymbolsDictKey"

struct TriangularsUpdaterJob: ScheduledJob {
    
    private let stableAssets: Set<String> = Set(arrayLiteral: "BUSD", "USDT", "USDC", "TUSD", "USD")
    private let forbiddenAssetsToTrade: Set<String> = Set(arrayLiteral: "RUB", "rub", "OP", "op")
    
    private let app: Application
    private let bot: TGBotPrtcl
    private let stockExchange: StockExchange
    
    init(app: Application, bot: TGBotPrtcl, stockEchange: StockExchange) {
        self.app = app
        self.bot = bot
        self.stockExchange = stockEchange
    }
    
    func run(context: Queues.QueueContext) -> NIOCore.EventLoopFuture<Void> {
        return context.eventLoop.performWithTask {
            switch stockExchange {
            case .binance:
                try await handleBinanceStockExchange()
            case .bybit:
                try await handleBybitStockExchange()
            case .huobi:
                try await handleHuobiStockExchange()
            }
        }
    }
    
    private func handleBinanceStockExchange() async throws {
        do {
            let tradeableSymbols = try await BinanceAPIService()
                .getExchangeInfo()
                .filter { $0.status == .trading && $0.isSpotTradingAllowed }

            let tradeableSymbolsDict = tradeableSymbols.toDictionary(with: { $0.symbol })
            try await app.caches.memory.set(binanceTradeableSymbolsDictKey, to: tradeableSymbolsDict)
            let tradeableSymbolsEndcodedData = try JSONEncoder().encode(tradeableSymbolsDict)
            try tradeableSymbolsEndcodedData.write(to: URL.binanceTradeableDict)
            
            let binanceStandartTriangulars = getTriangularsInfo(for: .standart, from: tradeableSymbols).triangulars
            let standartTriangularsEndcodedData = try JSONEncoder().encode(binanceStandartTriangulars)
            try standartTriangularsEndcodedData.write(to: URL.binanceStandartTriangularsStorageURL)

            let binanceStableTriangulars = getTriangularsInfo(for: .stable, from: tradeableSymbols).triangulars
            let stableTriangularsEndcodedData = try JSONEncoder().encode(binanceStableTriangulars)
            try stableTriangularsEndcodedData.write(to: URL.binanceStableTriangularsStorageURL)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    private func handleBybitStockExchange() async throws {
        do {
            let bybitTradeableSymbols = try await ByBitAPIService().getSymbols()
            
            let standartTriangularsInfo = self.getTriangularsInfo(for: .standart, from: bybitTradeableSymbols)
            let bybitStandartTriangulars = standartTriangularsInfo.triangulars
            
            let standartTriangularsEndcodedData = try JSONEncoder().encode(bybitStandartTriangulars)
            try standartTriangularsEndcodedData.write(to: URL.bybitStandartTriangularsStorageURL)
            
            let stableTriangularsInfo = self.getTriangularsInfo(for: .stable, from: bybitTradeableSymbols)
            let bybitStableTriangulars = stableTriangularsInfo.triangulars
            
            let stableTriangularsEndcodedData = try JSONEncoder().encode(bybitStableTriangulars)
            try stableTriangularsEndcodedData.write(to: URL.bybitStableTriangularsStorageURL)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    private func handleHuobiStockExchange() async throws {
        do {
            let huobiTradeableSymbols = try await HuobiAPIService.shared
                .getSymbolsInfo()
                .filter { $0.state == .online }
            
            let huobiStandartTriangulars = getTriangularsInfo(for: .standart, from: huobiTradeableSymbols).triangulars
            
            let standartTriangularsEndcodedData = try JSONEncoder().encode(huobiStandartTriangulars)
            try standartTriangularsEndcodedData.write(to: URL.huobiStandartTriangularsStorageURL)
            
            let huobiStableTriangulars = getTriangularsInfo(for: .stable, from: huobiTradeableSymbols).triangulars
            
            let stableTriangularsEndcodedData = try JSONEncoder().encode(huobiStableTriangulars)
            try stableTriangularsEndcodedData.write(to: URL.huobiStableTriangularsStorageURL)
        } catch {
            print(error.localizedDescription)
        }
    }
    
}

// MARK: - Helpers
private extension TriangularsUpdaterJob {
    
    func getTriangularsInfo(
        for mode: Mode,
        from tradeableSymbols: [TradeableSymbol]
    ) -> (triangulars: [Triangular], calculationDescription: String) {
        var removeDuplicates: Set<[String]> = Set()
        var triangulars: Set<Triangular> = Set()
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let duration: String
        let statusText: String
        
        switch mode {
        case .standart:
            // Get Pair A - Start from A
            for pairA in tradeableSymbols {
                let aBase: String = pairA.baseAsset
                let aQuote: String = pairA.quoteAsset
                
                guard forbiddenAssetsToTrade.contains(aBase) == false, forbiddenAssetsToTrade.contains(aQuote) == false else {
                    break
                }
                // Get Pair B - Find B pair where one coint matched
                for pairB in tradeableSymbols {
                    let bBase: String = pairB.baseAsset
                    let bQuote: String = pairB.quoteAsset
                    
                    if pairB.symbol != pairA.symbol {
                        if (aBase == bBase || aQuote == bBase) ||
                            (aBase == bQuote || aQuote == bQuote) {
                            
                            // Get Pair C - Find C pair where base and quote exist in A and B configurations
                            for pairC in tradeableSymbols {
                                let cBase: String = pairC.baseAsset
                                let cQuote: String = pairC.quoteAsset
                                
                                // Count the number of matching C items
                                if pairC.symbol != pairA.symbol && pairC.symbol != pairB.symbol {
                                    let pairBox: [String] = [aBase, aQuote, bBase, bQuote, cBase, cQuote]
                                    
                                    let cBaseCount = pairBox.filter { $0 == cBase }.count
                                    let cQuoteCount = pairBox.filter { $0 == cQuote }.count
                                    
                                    // Determining Triangular Match
                                    if cBaseCount == 2 && cQuoteCount == 2 && cBase != cQuote {
                                        let combineAll = [pairA.symbol, pairB.symbol, pairC.symbol]
                                        let uniqueItem = combineAll.sorted()
                                        
                                        if removeDuplicates.contains(uniqueItem) == false {
                                            removeDuplicates.insert(uniqueItem)
                                            triangulars.insert(Triangular(aBase: aBase,
                                                                          bBase: bBase,
                                                                          cBase: cBase,
                                                                          aQuote: aQuote,
                                                                          bQuote: bQuote,
                                                                          cQuote: cQuote,
                                                                          pairA: pairA.symbol,
                                                                          pairB: pairB.symbol,
                                                                          pairC: pairC.symbol))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            duration = String(format: "%.4f", CFAbsoluteTimeGetCurrent() - startTime)
            statusText = "[Standart Triangulars] Calculated \(triangulars.count) from \(tradeableSymbols.count) symbols in \(duration) seconds (last updated  \(Date().readableDescription))"
            
        case .stable:
            for pairA in tradeableSymbols {
                let aBase: String = pairA.baseAsset
                let aQuote: String = pairA.quoteAsset
                
                if (stableAssets.contains(aBase) && stableAssets.contains(aQuote) == false) ||
                    (stableAssets.contains(aBase) == false && stableAssets.contains(aQuote)) {
                    // Get Pair B - Find B pair where one coin matched
                    for pairB in tradeableSymbols {
                        let bBase: String = pairB.baseAsset
                        let bQuote: String = pairB.quoteAsset
                        
                        if pairB.symbol != pairA.symbol && ((aBase == bBase || aQuote == bBase) || (aBase == bQuote || aQuote == bQuote)) {
                            
                            // Get Pair C - Find C pair where base and quote exist in A and B configurations
                            for pairC in tradeableSymbols {
                                let cBase: String = pairC.baseAsset
                                let cQuote: String = pairC.quoteAsset
                                
                                // Count the number of matching C items
                                if pairC.symbol != pairA.symbol && pairC.symbol != pairB.symbol {
                                    let pairBox: [String] = [aBase, aQuote, bBase, bQuote, cBase, cQuote]
                                    
                                    let cBaseCount = pairBox.filter { $0 == cBase }.count
                                    let cQuoteCount = pairBox.filter { $0 == cQuote }.count
                                    
                                    // Determining Triangular Match
                                    // The End should be stable
                                    // TODO: - the end should be any Stable
                                    if (cBaseCount == 2 && stableAssets.contains(cQuote)) || (stableAssets.contains(cBase) && cQuoteCount == 2) {
                                        let combineAll = [pairA.symbol, pairB.symbol, pairC.symbol]
                                        let uniqueItem = combineAll.sorted()
                                        
                                        if removeDuplicates.contains(uniqueItem) == false {
                                            removeDuplicates.insert(uniqueItem)
                                            triangulars.insert(Triangular(aBase: aBase,
                                                                          bBase: bBase,
                                                                          cBase: cBase,
                                                                          aQuote: aQuote,
                                                                          bQuote: bQuote,
                                                                          cQuote: cQuote,
                                                                          pairA: pairA.symbol,
                                                                          pairB: pairB.symbol,
                                                                          pairC: pairC.symbol))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            duration = String(format: "%.4f", CFAbsoluteTimeGetCurrent() - startTime)
            statusText = "[Stable Triangulars] Calculated \(triangulars.count) from \(tradeableSymbols.count) symbols in \(duration) seconds (last updated \(Date().readableDescription))"
        }

        return (Array(triangulars), statusText)
    }
    
}
