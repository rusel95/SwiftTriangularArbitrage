//
//  ArbitrageCalculator.swift
//  
//
//  Created by Ruslan on 30.08.2022.
//

import Foundation
import CoreFoundation
import Jobs
import Logging

final class ArbitrageCalculator {
    
    // MARK: - Structs
    
    enum Mode {
        case standart
        case stable
        
        var description: String {
            switch self {
            case .standart:
                return "[Standart]"
            case .stable:
                return "[Stable]"
            }
        }
    }
    
    // MARK: - Properties
    
    static let shared = ArbitrageCalculator()
    
    private var tradeableSymbols: [BinanceAPIService.Symbol] = []
    private var bookTickersDictionary: [String: BinanceAPIService.BookTicker] = [:]
    private var currentStandartTriangulars: [Triangular] = []
    private var currentStableTriangulars: [Triangular] = []
    
    private var lastStandartTriangularsStatusText: String = ""
    private var lastStableTriangularsStatusText: String = ""
    private var logger = Logger(label: "logget.artitrage.triangular")
    private var isFirstUpdateCycle: Bool = true
    
    private var documentsDirectory: URL {
#if os(OSX)
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
#else
        return URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)")
#endif
    }
    
    private var triangularsStorageURL: URL {
        documentsDirectory.appendingPathComponent("triangulars")
    }
    private var stableTriangularsStorageURL: URL {
        documentsDirectory.appendingPathComponent("stable_triangulars")
    }
    
    private let symbolsWithoutComissions: Set<String> = Set(arrayLiteral: "BTCAUD", "BTCBIDR", "BTCBRL", "BTCBUSD", "BTCEUR", "BTCGBP", "BTCRUB", "BTCTRY", "BTCTUSD", "BTC/UAH", "BTCUSDC", "BTCUSDP", "BTCUSDT", "ETHBUSD")
    private let stables: Set<String> = Set(arrayLiteral: "BUSD", "USDT", "USDC", "TUSD")
    
    // MARK: - Init
    
    private init() {
        Jobs.add(interval: .seconds(1800)) { [weak self] in
            guard let self = self else { return }
            
            if self.isFirstUpdateCycle {
                do {
                    let standartTriangularsJsonData = try Data(contentsOf: self.triangularsStorageURL)
                    self.currentStandartTriangulars = try JSONDecoder().decode([Triangular].self, from: standartTriangularsJsonData)
                    
                    let stableTriangularsJsonData = try Data(contentsOf: self.stableTriangularsStorageURL)
                    self.currentStableTriangulars = try JSONDecoder().decode([Triangular].self, from: stableTriangularsJsonData)
                } catch {
                    self.logger.critical(Logger.Message(stringLiteral: error.localizedDescription))
                }
                self.isFirstUpdateCycle = false
            } else {
                BinanceAPIService.shared.getExchangeInfo { [weak self] symbols in
                    guard let self = self, let symbols = symbols else { return }
                    
                    self.tradeableSymbols = symbols.filter { $0.status == .trading && $0.isSpotTradingAllowed }
                    
                    let standartTriangularsInfo = self.getTriangularsInfo(for: .standart, from: self.tradeableSymbols)
                    self.currentStandartTriangulars = standartTriangularsInfo.triangulars
                    self.lastStandartTriangularsStatusText = standartTriangularsInfo.calculationDescription
                    
                    do {
                        let standartTriangularsEndcodedData = try JSONEncoder().encode(self.currentStandartTriangulars)
                        try standartTriangularsEndcodedData.write(to: self.triangularsStorageURL)
                    } catch {
                        self.logger.critical(Logger.Message(stringLiteral: error.localizedDescription))
                    }
                    
                    let stableTriangularsInfo = self.getTriangularsInfo(for: .stable, from: self.tradeableSymbols)
                    self.currentStableTriangulars = stableTriangularsInfo.triangulars
                    self.lastStableTriangularsStatusText = stableTriangularsInfo.calculationDescription
                    
                    do {
                        let standartTriangularsEndcodedData = try JSONEncoder().encode(self.currentStandartTriangulars)
                        try standartTriangularsEndcodedData.write(to: self.triangularsStorageURL)
                        
                        let stableTriangularsEndcodedData = try JSONEncoder().encode(self.currentStableTriangulars)
                        try stableTriangularsEndcodedData.write(to: self.stableTriangularsStorageURL)
                    } catch {
                        self.logger.critical(Logger.Message(stringLiteral: error.localizedDescription))
                    }
                }
            }
        }
    }
    
    // MARK: Getting Surface Results
    
    func getSurfaceResults(for mode: Mode, completion: @escaping ([SurfaceResult]?, String) -> Void) {
        BinanceAPIService.shared.getAllBookTickers { [weak self] tickers in
            guard let self = self, let tickers = tickers else { return }
            
            self.bookTickersDictionary = tickers.toDictionary { $0.symbol }
            
            var allSurfaceResults: [SurfaceResult] = []
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            let duration: String
            let statusText: String
            switch mode {
            case .standart:
                self.currentStandartTriangulars.forEach { triangular in
                    if let surfaceResult = self.calculateSurfaceRate(mode: .standart, triangular: triangular) {
                        allSurfaceResults.append(surfaceResult)
                    }
                }
                duration = String(format: "%.4f", CFAbsoluteTimeGetCurrent() - startTime)
                statusText = "\n\(self.lastStandartTriangularsStatusText)\n[Standart] Calculated Profits for \(self.currentStandartTriangulars.count) triangulars at \(self.tradeableSymbols.count) symbols in \(duration) seconds"
            case .stable:
                self.currentStableTriangulars.forEach { triangular in
                    if let surfaceResult = self.calculateSurfaceRate(mode: .stable, triangular: triangular) {
                        allSurfaceResults.append(surfaceResult)
                    }
                }
                duration = String(format: "%.4f", CFAbsoluteTimeGetCurrent() - startTime)
                statusText = "\n\(self.lastStableTriangularsStatusText)\n[Stable] Calculated Profits for \(self.currentStableTriangulars.count) triangulars at \(self.tradeableSymbols.count) symbols in \(duration) seconds"
            }
            
            let valuableSurfaceResults = allSurfaceResults
                .sorted(by: { $0.profitPercent > $1.profitPercent })
                .prefix(10)
            completion(Array(valuableSurfaceResults), statusText)
        }
    }
}

// MARK: - Collect Triangles

private extension ArbitrageCalculator {
    
    func getTriangularsInfo(
        for mode: Mode,
        from tradeableSymbols: [BinanceAPIService.Symbol]
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
                
                if (stables.contains(aBase) && stables.contains(aQuote) == false) ||
                    (stables.contains(aBase) == false && stables.contains(aQuote)) {
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
                                    if (cBaseCount == 2 && stables.contains(cQuote)) || (stables.contains(cBase) && cQuoteCount == 2) {
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

// MARK: - Calculate Triangular's Surface Rate

private extension ArbitrageCalculator {
    
    func calculateSurfaceRate(mode: Mode, triangular: Triangular) -> SurfaceResult? {
        let startingAmount: Double = 1.0
        
        var contract1 = ""
        var contract2 = ""
        var contract3 = ""
        
        var directionTrade1 = ""
        var directionTrade2 = ""
        var directionTrade3 = ""
        
        var acquiredCoinT1: Double = 0.0
        var acquiredCoinT2: Double = 0.0
        var acquiredCoinT3: Double = 0.0
        
        let aBase = triangular.aBase
        let aQuote = triangular.aQuote
        let bBase = triangular.bBase
        let bQuote = triangular.bQuote
        let cBase = triangular.cBase
        let cQuote = triangular.cQuote
        let pairA = triangular.pairA
        let pairB = triangular.pairB
        let pairC = triangular.pairC
        
        let pairAComissionMultipler = getCommissionMultipler(symbol: pairA)
        let pairBComissionMultipler = getCommissionMultipler(symbol: pairB)
        let pairCComissionMultipler = getCommissionMultipler(symbol: pairC)

        guard let pairAPrice = bookTickersDictionary[triangular.pairA],
              let aAsk = Double(pairAPrice.askPrice),
              let aBid = Double(pairAPrice.bidPrice),
              let pairBPrice = bookTickersDictionary[triangular.pairB],
              let bAsk = Double(pairBPrice.askPrice),
              let bBid = Double(pairBPrice.bidPrice),
              let pairCPrice = bookTickersDictionary[triangular.pairC],
              let cAsk = Double(pairCPrice.askPrice),
              let cBid = Double(pairCPrice.bidPrice) else {
            logger.critical("No prices for \(triangular)")
            return nil
        }

        // Set direction and loop through
        let directionsList: [SurfaceResult.Direction] = [.forward, .reverse]
        for direction in directionsList {
            // Set additional variables for swap information
            var swap0 = ""
            var swap1 = ""
            var swap2 = ""
            var swap3 = ""
            var swap1Rate: Double = 0.0
            var swap2Rate: Double = 0.0
            var swap3Rate: Double = 0.0
            
            // If we are swapping the coin on the left (Base) to the right (Quote) then * (1 / Ask)
            // If we are swapping the coin on the right (Quite) to the left (Base) then * Bid
            
            // Assume starting aBase and swapping for aQuote
            
            switch direction {
            case .forward:
                swap0 = aBase
                swap1 = aQuote
                swap1Rate = aBid
                directionTrade1 = "base_to_quote"
            case .reverse:
                swap0 = aQuote
                swap1 = aBase
                swap1Rate = 1.0 / aAsk
                directionTrade1 = "quote_to_base"
            }
            
            switch mode {
            case .standart: break
            case .stable:
                if stables.contains(swap0) {
                    break
                } else {
                    return nil
                }
            }
            
            // Place first trade
            contract1 = pairA
            acquiredCoinT1 = startingAmount * swap1Rate * pairAComissionMultipler
            
            // TODO: - only once scenario at a time can be used - so need to use "else if"
            /* FORWARD */
            // MARK: SCENARIO 1
            // Check if aQoute (acquired coin) matches bQuote
            if direction == .forward {
                if aQuote == bQuote {
                    swap2Rate = 1.0 / bAsk
                    acquiredCoinT2 = acquiredCoinT1 * swap2Rate * pairBComissionMultipler
                    directionTrade2 = "quote_to_base"
                    contract2 = pairB
                    
                    // if bBase (aquiredCoin) mathces cBase
                    if bBase == cBase {
                        swap2 = cBase
                        swap3 = cQuote
                        swap3Rate = cBid
                        directionTrade3 = "base_to_quote"
                        contract3 = pairC
                    }
                    
                    // if bBase (aquired coin) mathces cQuote
                    if bBase == cQuote {
                        swap2 = cQuote
                        swap3 = cBase
                        swap3Rate = 1.0 / cAsk
                        directionTrade3 = "quote_to_base"
                        contract3 = pairC
                    }
                    
                    acquiredCoinT3 = acquiredCoinT2 * swap3Rate * pairAComissionMultipler
                }
                
                // MARK: SCENARIO 2
                // Check if aQoute (acquired coin) matches bBase
                else if aQuote == bBase {
                    swap2Rate = bBid
                    acquiredCoinT2 = acquiredCoinT1 * swap2Rate * pairBComissionMultipler
                    directionTrade2 = "base_to_qoute"
                    contract2 = pairB
                    
                    // if bQuote (aquired coin) mathces cBase
                    if bBase == cBase {
                        swap2 = cBase
                        swap3 = cQuote
                        swap3Rate = cBid
                        directionTrade3 = "base_to_quote"
                        contract3 = pairC
                    }
                    
                    // if bQoute (aquired coin) mathces cQuote
                    if bQuote == cQuote {
                        swap2 = cQuote
                        swap3 = cBase
                        swap3Rate = 1.0 / cAsk
                        directionTrade3 = "quote_to_base"
                        contract3 = pairC
                    }
                    
                    acquiredCoinT3 = acquiredCoinT2 * swap3Rate * pairCComissionMultipler
                }
                // MARK: SCENARIO 3
                // Check if aQoute (aquired coin) matches cQuote
                else if aQuote == cQuote {
                    swap2Rate = 1.0 / cAsk
                    acquiredCoinT2 = acquiredCoinT1 * swap2Rate * pairCComissionMultipler
                    directionTrade2 = "quote_to_base"
                    contract2 = pairC
                    
                    // if cBase (aquired coin) mathces bBase
                    if cBase == bBase {
                        swap2 = bBase
                        swap3 = bQuote
                        swap3Rate = bBid
                        directionTrade3 = "base_to_quote"
                        contract3 = pairB
                    }
                    
                    // if cBase (aquired coin) mathces bQuote
                    if cBase == bQuote {
                        swap2 = bQuote
                        swap3 = bBase
                        swap3Rate = 1.0 / bAsk
                        directionTrade3 = "quote_to_base"
                        contract3 = pairB
                    }
                    
                    acquiredCoinT3 = acquiredCoinT2 * swap3Rate * pairCComissionMultipler
                }
                // MARK: SCENARIO 4
                // Check if aQoute (aquired coin) matches cBase
                else if aQuote == cBase {
                    swap2Rate = cBid
                    acquiredCoinT2 = acquiredCoinT1 * swap2Rate * pairCComissionMultipler
                    directionTrade2 = "quote_to_base"
                    contract2 = pairC
                    
                    // if cQuote (aquired coin) mathces bBase
                    if cQuote == bBase {
                        swap2 = bBase
                        swap3 = bQuote
                        swap3Rate = bBid
                        directionTrade3 = "base_to_quote"
                        contract3 = pairB
                    }
                    
                    // if cQuote (aquired coin) mathces bQuote
                    if cQuote == bQuote {
                        swap2 = bQuote
                        swap3 = bBase
                        swap3Rate = 1.0 / bAsk
                        directionTrade3 = "quote_to_base"
                        contract3 = pairB
                    }
                    
                    acquiredCoinT3 = acquiredCoinT2 * swap3Rate * pairBComissionMultipler
                }
            }
            /* REVERSE */
            // MARK: SCENARIO 5
            // Check if aBase (aquired coin) matches bQuote
            if direction == .reverse {
                if aBase == bQuote {
                    swap2Rate = 1.0 / bAsk
                    acquiredCoinT2 = acquiredCoinT1 * swap2Rate * pairBComissionMultipler
                    directionTrade2 = "quote_to_base"
                    contract2 = pairB
                    
                    // if bBase (aquired coin) mathces cBase
                    if bBase == cBase {
                        swap2 = cBase
                        swap3 = cQuote
                        swap3Rate = cBid
                        directionTrade3 = "base_to_quote"
                        contract3 = pairC
                    }
                    
                    // if bBase (aquired coin) mathces cQuote
                    if bBase == cQuote {
                        swap2 = cQuote
                        swap3 = cBase
                        swap3Rate = 1.0 / cAsk
                        directionTrade3 = "quote_to_base"
                        contract3 = pairC
                    }
                    
                    acquiredCoinT3 = acquiredCoinT2 * swap3Rate * pairCComissionMultipler
                }
                // MARK: SCENARIO 6
                // Check if aBase (aquired coin) matches bBase
                else if aBase == bBase {
                    swap2Rate = bBid
                    acquiredCoinT2 = acquiredCoinT1 * swap2Rate * pairBComissionMultipler
                    directionTrade2 = "base_to_qoute"
                    contract2 = pairB
                    
                    // if bQuote (aquired coin) mathces cBase
                    if bBase == cBase {
                        swap2 = cBase
                        swap3 = cQuote
                        swap3Rate = cBid
                        directionTrade3 = "base_to_quote"
                        contract3 = pairC
                    }
                    
                    // if bQoute (aquired coin) mathces cQuote
                    if bQuote == cQuote {
                        swap2 = cQuote
                        swap3 = cBase
                        swap3Rate = 1.0 / cAsk
                        directionTrade3 = "quote_to_base"
                        contract3 = pairC
                    }
                    
                    acquiredCoinT3 = acquiredCoinT2 * swap3Rate * pairCComissionMultipler
                }
                // MARK: SCENARIO 7
                // Check if aBase (aquired coin) matches cQuote
                else if aBase == cQuote {
                    swap2Rate = 1.0 / cAsk
                    acquiredCoinT2 = acquiredCoinT1 * swap2Rate * pairCComissionMultipler
                    directionTrade2 = "quote_to_base"
                    contract2 = pairC
                    
                    // if cBase (aquired coin) mathces bBase
                    if cBase == bBase {
                        swap2 = bBase
                        swap3 = bQuote
                        swap3Rate = bBid
                        directionTrade3 = "base_to_quote"
                        contract3 = pairB
                    }
                    
                    // if bBase (aquired coin) mathces bQuote
                    if cBase == bQuote {
                        swap2 = bQuote
                        swap3 = bBase
                        swap3Rate = 1.0 / bAsk
                        directionTrade3 = "quote_to_base"
                        contract3 = pairB
                    }
                    
                    acquiredCoinT3 = acquiredCoinT2 * swap3Rate * pairBComissionMultipler
                }
                // MARK: SCENARIO 8
                // Check if aBase (aquired coin) atches cBase
                else if aBase == cBase {
                    swap2Rate = cBid
                    acquiredCoinT2 = acquiredCoinT1 * swap2Rate * pairCComissionMultipler
                    directionTrade2 = "base_to_quote"
                    contract2 = pairC
                    
                    // if cQuote (aquired coin) mathces bBase
                    if cQuote == bBase {
                        swap2 = bBase
                        swap3 = bQuote
                        swap3Rate = bBid
                        directionTrade3 = "base_to_quote"
                        contract3 = pairB
                    }
                    
                    // if cQuote (aquired coin) mathces bQuote
                    if cQuote == bQuote {
                        swap2 = bQuote
                        swap3 = bBase
                        swap3Rate = 1.0 / bAsk
                        directionTrade3 = "quote_to_base"
                        contract3 = pairB
                    }
                    
                    acquiredCoinT3 = acquiredCoinT2 * swap3Rate * pairBComissionMultipler
                }
            }
            
            // MARK: Profit Loss ouput
            let profit = acquiredCoinT3 - startingAmount
            let profitPercent = (profit / startingAmount) * 100.0
            
            // Output results
            if profitPercent > -0.3 {
                return SurfaceResult(
                    modeDescrion: mode.description,
                    swap0: swap0,
                    swap1: swap1,
                    swap2: swap2,
                    swap3: swap3,
                    contract1: contract1,
                    contract2: contract2,
                    contract3: contract3,
                    directionTrade1: directionTrade1,
                    directionTrade2: directionTrade2,
                    directionTrade3: directionTrade3,
                    acquiredCoinT1: acquiredCoinT1,
                    acquiredCoinT2: acquiredCoinT2,
                    acquiredCoinT3: acquiredCoinT3,
                    swap1Rate: swap1Rate,
                    swap2Rate: swap2Rate,
                    swap3Rate: swap3Rate,
                    profitPercent: profitPercent,
                    direction: direction
                )
            }
        }
        
        return nil
    }
    
    func getCommissionMultipler(symbol: String) -> Double {
        let comissionPercent = symbolsWithoutComissions.contains(symbol) ? 0 : 0.075
        return 1.0 - comissionPercent / 100.0
    }
    
}
