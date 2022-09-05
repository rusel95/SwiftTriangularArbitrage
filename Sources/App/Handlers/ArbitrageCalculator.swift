//
//  ArbitrageCalculator.swift
//  
//
//  Created by Ruslan on 30.08.2022.
//

import Foundation
import CoreFoundation
import Jobs

final class ArbitrageCalculator {
    
    // MARK: - Structs
    
    struct SurfaceResult {
        
        enum Direction: String {
            case forward
            case reverse
        }
        
        let swap1: String
        let swap2: String
        let swap3: String
        let contract1: String
        let contract2: String
        let contract3: String
        let directionTrade1: String
        let directionTrade2: String
        let directionTrade3: String
        let acquiredCoinT1: Double
        let acquiredCoinT2: Double
        let acquiredCoinT3: Double
        let swap1Rate: Double
        let swap2Rate: Double
        let swap3Rate: Double
        let profitLossPercent: Double
        let direction: Direction
        let tradeDescription1: String
        let tradeDescription2: String
        let tradeDescription3: String
    }
    
    struct Triangular: Hashable, Equatable {
        let aBase: String
        let bBase: String
        let cBase: String
        let aQuote: String
        let bQuote: String
        let cQuote: String
        let pairA: String
        let pairB: String
        let pairC: String
        let combined: String
    }
    
    // MARK: - Properties
    
    static let shared = ArbitrageCalculator()
    
    private var currentTriangulars: [Triangular] = []
    private var currentBookTickers: [BinanceAPIService.BookTicker]? = nil
    private var surfaceResults: [SurfaceResult] = []
    
    private let dispatchQueue = DispatchQueue(label: "com.p2pHelper", attributes: .concurrent)
    
    private var triangularsCalculationRestictAmount: Int {
#if DEBUG
        return 500
#else
        return 400 // TODO: - optimize to get full amout
#endif
    }
    
    private var lastTriangularsStatusText: String = ""
    
    // MARK: - Init
    
    private init() {
        Jobs.add(interval: .hours(6)) { [weak self] in
            BinanceAPIService.shared.getExchangeInfo { [weak self] symbols in
                guard let self = self, let symbols = symbols else { return }
                
                let triangularsInfo = self.getTriangulars(from: symbols)
                self.currentTriangulars = triangularsInfo.0
                self.lastTriangularsStatusText = triangularsInfo.1
            }
        }
    }
    
    // MARK: - Methods
    
    func getSurfaceResults(completion: @escaping ([SurfaceResult]?, String) -> Void) {
        BinanceAPIService.shared.getAllBookTickers { [weak self] tickers in
            guard let self = self, tickers?.isEmpty == false else { return }
            
            self.currentBookTickers = tickers
            var surfaceResults: [SurfaceResult] = []
            
            let startTime = CFAbsoluteTimeGetCurrent()
            DispatchQueue.concurrentPerform(iterations: self.currentTriangulars.count) { i in
                guard let surfaceResult = self.calculateSurfaceRate(triangular: self.currentTriangulars[i]) else { return }
                
                self.dispatchQueue.async(flags: .barrier) {
                    surfaceResults.append(surfaceResult)
                }
            }
            let duration = String(format: "%.2f", CFAbsoluteTimeGetCurrent() - startTime)
            let statusText = "\n \(self.lastTriangularsStatusText)\nCalculated Profits for \(self.currentTriangulars.count) triangulars in \(duration) seconds"
            completion(surfaceResults, statusText)
        }
    }
    
    // MARK: - Collect Triangles
    private func getTriangulars(from symbols: [BinanceAPIService.Symbol]) -> ([Triangular], String) {
        let pairsToCount = symbols
            .filter { $0.status == .trading }
            .prefix(triangularsCalculationRestictAmount)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        var removeDuplicatesSet: Set<[String]> = Set()
        var triangulars: [Triangular] = []
        
        // Get Pair A - Start from A
        DispatchQueue.concurrentPerform(iterations: pairsToCount.count) { i in
            let pairA = pairsToCount[i]
            let aBase: String = pairA.baseAsset
            let aQuote: String = pairA.quoteAsset
            
            // Get Pair B - Find B pair where one coint matched
            for pairB in pairsToCount {
                let bBase: String = pairB.baseAsset
                let bQuote: String = pairB.quoteAsset
                
                if pairB.symbol != pairA.symbol {
                    if (aBase == bBase || aQuote == bBase) ||
                        (aBase == bQuote || aQuote == bQuote) {
                        
                        // Get Pair C - Find C pair where base and quote exist in A and B configurations
                        for pairC in pairsToCount {
                            let cBase: String = pairC.baseAsset
                            let cQuote: String = pairC.quoteAsset
                            
                            // Count the number of matching C items
                            if pairC.symbol != pairA.symbol && pairC.symbol != pairB.symbol {
                                let combineAll = [pairA.symbol, pairB.symbol, pairC.symbol]
                                let pairBox: [String] = [aBase, aQuote, bBase, bQuote, cBase, cQuote]
                                
                                let cBaseCount = pairBox.filter { $0 == cBase }.count
                                let cQuoteCount = pairBox.filter { $0 == cQuote }.count
                                
                                // Determining Triangular Match
                                if cBaseCount == 2 && cQuoteCount == 2 && cBase != cQuote {
                                    let uniqueItem = combineAll.sorted()
                                    
                                    dispatchQueue.async(flags: .barrier) {
                                        if removeDuplicatesSet.contains(uniqueItem) == false {
                                            removeDuplicatesSet.insert(uniqueItem)
                                            triangulars.append(Triangular(aBase: aBase,
                                                                          bBase: bBase,
                                                                          cBase: cBase,
                                                                          aQuote: aQuote,
                                                                          bQuote: bQuote,
                                                                          cQuote: cQuote,
                                                                          pairA: pairA.symbol,
                                                                          pairB: pairB.symbol,
                                                                          pairC: pairC.symbol,
                                                                          combined: uniqueItem.joined(separator: "_")))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        let statusText = "Calculated \(triangulars.count) Triangulars from \(self.triangularsCalculationRestictAmount) symbols in \(CFAbsoluteTimeGetCurrent() - startTime) seconds"
        return (triangulars, statusText)
    }
    
    
    
    // MARK: - Calculate Surface Rates
    private func calculateSurfaceRate(triangular: Triangular) -> SurfaceResult? {
        // Set Variables
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
        
        var calculated: Double = 0.0
        
        let aBase = triangular.aBase
        let aQuote = triangular.aQuote
        let bBase = triangular.bBase
        let bQuote = triangular.bQuote
        let cBase = triangular.cBase
        let cQuote = triangular.cQuote
        let pairA = triangular.pairA
        let pairB = triangular.pairB
        let pairC = triangular.pairC
        
        guard let prices = getCurrentPrices(triangular: triangular) else { return nil }
        
        let aAsk: Double = prices.pairAAsk
        let aBid: Double = prices.pairABid
        let bAsk: Double = prices.pairBAsk
        let bBid: Double = prices.pairBBid
        let cAsk: Double = prices.pairCAsk
        let cBid: Double = prices.pairCBid
        
        // Set direction and loop through
        let directionsList: [SurfaceResult.Direction] = [.forward, .reverse]
        for direction in directionsList {
            // Set additional variables for swap information
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
                swap1 = aBase
                swap2 = aQuote
                swap1Rate = 1.0 / aAsk
                directionTrade1 = "base_to_quote"
            case .reverse:
                swap1 = aQuote
                swap2 = aBase
                swap1Rate = aBid
                directionTrade1 = "quote_to_base"
            }
            // Place first trade
            contract1 = pairA
            acquiredCoinT1 = startingAmount * swap1Rate
            
            /* FORWARD */
            // MARK: SCENARIO 1
            // Check if aQoute (acquired_coun) batches bQuote
            if direction == .forward {
                if aQuote == bQuote && calculated == 0 {
                    swap2Rate = bBid
                    acquiredCoinT2 = acquiredCoinT1 * swap2Rate
                    directionTrade2 = "quote_to_base"
                    contract2 = pairB
                    
                    // if bBase (aquiredCoin) mathces cBase
                    if bBase == cBase {
                        swap3 = cBase
                        swap3Rate = 1.0 / cAsk
                        directionTrade3 = "base_to_quote"
                        contract3 = pairC
                    }
                    
                    // if bBase (aquiredCoin) mathces cQuote
                    if bBase == cQuote {
                        swap3 = cQuote
                        swap3Rate = cBid
                        directionTrade3 = "quote_to_base"
                        contract3 = pairC
                    }
                    
                    acquiredCoinT3 = acquiredCoinT2 * swap3Rate
                    calculated = 1
                }
                
            }
            
            // MARK: SCENARIO 2
            // Check if aQoute (acquired_coun) batches bBase
            if direction == .forward {
                if aQuote == bBase && calculated == 0 {
                    swap2Rate = 1.0 / bAsk
                    acquiredCoinT2 = acquiredCoinT1 * swap2Rate
                    directionTrade2 = "base_to_qoute"
                    contract2 = pairB
                    
                    // if bQuote (aquiredCoin) mathces cBase
                    if bBase == cBase {
                        swap3 = cBase
                        swap3Rate = 1.0 / cAsk
                        directionTrade3 = "base_to_quote"
                        contract3 = pairC
                    }
                    
                    // if bQoute (aquiredCoin) mathces cQuote
                    if bQuote == cQuote {
                        swap3 = cQuote
                        swap3Rate = cBid
                        directionTrade3 = "quote_to_base"
                        contract3 = pairC
                    }
                    
                    acquiredCoinT3 = acquiredCoinT2 * swap3Rate
                    calculated = 1
                }
            }
            
            // MARK: SCENARIO 3
            // Check if aQoute (acquired_coun) batches cQuote
            if direction == .forward {
                if aQuote == cQuote && calculated == 0 {
                    swap2Rate = cBid
                    acquiredCoinT2 = acquiredCoinT1 * swap2Rate
                    directionTrade2 = "quote_to_base"
                    contract2 = pairC
                    
                    // if cBase (aquiredCoin) mathces bBase
                    if cBase == bBase {
                        swap3 = bBase
                        swap3Rate = 1.0 / bAsk
                        directionTrade3 = "base_to_quote"
                        contract3 = pairB
                    }
                    
                    // if bBase (aquiredCoin) mathces bQuote
                    if cBase == bQuote {
                        swap3 = bQuote
                        swap3Rate = bBid
                        directionTrade3 = "quote_to_base"
                        contract3 = pairB
                    }
                    
                    acquiredCoinT3 = acquiredCoinT2 * swap3Rate
                    calculated = 1
                }
            }
            
            // MARK: SCENARIO 4
            // Check if aQoute (acquired_coun) batches cBase
            if direction == .forward {
                if aQuote == cBase && calculated == 0 {
                    swap2Rate = 1.0 / cAsk
                    acquiredCoinT2 = acquiredCoinT1 * swap2Rate
                    directionTrade2 = "quote_to_base"
                    contract2 = pairC
                    
                    // if cQuote (aquiredCoin) mathces bBase
                    if cQuote == bBase {
                        swap3 = bBase
                        swap3Rate = 1.0 / bAsk
                        directionTrade3 = "base_to_quote"
                        contract3 = pairB
                    }
                    
                    // if cQuote (aquiredCoin) mathces bQuote
                    if cQuote == bQuote {
                        swap3 = bQuote
                        swap3Rate = bBid
                        directionTrade3 = "quote_to_base"
                        contract3 = pairB
                    }
                    
                    acquiredCoinT3 = acquiredCoinT2 * swap3Rate
                    calculated = 1
                }
            }
            
            /* REVERSE */
            // MARK: SCENARIO 5
            // Check if aBase (acquired_coun) batches bQuote
            if direction == .reverse {
                if aBase == bQuote && calculated == 0 {
                    swap2Rate = bBid
                    acquiredCoinT2 = acquiredCoinT1 * swap2Rate
                    directionTrade2 = "quote_to_base"
                    contract2 = pairB
                    
                    // if bBase (aquiredCoin) mathces cBase
                    if bBase == cBase {
                        swap3 = cBase
                        swap3Rate = 1.0 / cAsk
                        directionTrade3 = "base_to_quote"
                        contract3 = pairC
                    }
                    
                    // if bBase (aquiredCoin) mathces cQuote
                    if bBase == cQuote {
                        swap3 = cQuote
                        swap3Rate = cBid
                        directionTrade3 = "quote_to_base"
                        contract3 = pairC
                    }
                    
                    acquiredCoinT3 = acquiredCoinT2 * swap3Rate
                    calculated = 1
                }
                
            }
            
            // MARK: SCENARIO 6
            // Check if aBase (acquired_coun) batches bBase
            if direction == .reverse {
                if aBase == bBase && calculated == 0 {
                    swap2Rate = 1.0 / bAsk
                    acquiredCoinT2 = acquiredCoinT1 * swap2Rate
                    directionTrade2 = "base_to_qoute"
                    contract2 = pairB
                    
                    // if bQuote (aquiredCoin) mathces cBase
                    if bBase == cBase {
                        swap3 = cBase
                        swap3Rate = 1.0 / cAsk
                        directionTrade3 = "base_to_quote"
                        contract3 = pairC
                    }
                    
                    // if bQoute (aquiredCoin) mathces cQuote
                    if bQuote == cQuote {
                        swap3 = cQuote
                        swap3Rate = cBid
                        directionTrade3 = "quote_to_base"
                        contract3 = pairC
                    }
                    
                    acquiredCoinT3 = acquiredCoinT2 * swap3Rate
                    calculated = 1
                }
            }
            
            // MARK: SCENARIO 7
            // Check if aBase (acquired_coun) batches cQuote
            if direction == .reverse {
                if aBase == cQuote && calculated == 0 {
                    swap2Rate = cBid
                    acquiredCoinT2 = acquiredCoinT1 * swap2Rate
                    directionTrade2 = "quote_to_base"
                    contract2 = pairC
                    
                    // if cBase (aquiredCoin) mathces bBase
                    if cBase == bBase {
                        swap3 = bBase
                        swap3Rate = 1.0 / bAsk
                        directionTrade3 = "base_to_quote"
                        contract3 = pairB
                    }
                    
                    // if bBase (aquiredCoin) mathces bQuote
                    if cBase == bQuote {
                        swap3 = bQuote
                        swap3Rate = bBid
                        directionTrade3 = "quote_to_base"
                        contract3 = pairB
                    }
                    
                    acquiredCoinT3 = acquiredCoinT2 * swap3Rate
                    calculated = 1
                }
            }
            
            // MARK: SCENARIO 8
            // Check if aBase (acquired_coun) batches cBase
            if direction == .reverse {
                if aBase == cBase && calculated == 0 {
                    swap2Rate = 1.0 / cAsk
                    acquiredCoinT2 = acquiredCoinT1 * swap2Rate
                    directionTrade2 = "quote_to_base"
                    contract2 = pairC
                    
                    // if cQuote (aquiredCoin) mathces bBase
                    if cQuote == bBase {
                        swap3 = bBase
                        swap3Rate = 1.0 / bAsk
                        directionTrade3 = "base_to_quote"
                        contract3 = pairB
                    }
                    
                    // if cQuote (aquiredCoin) mathces bQuote
                    if cQuote == bQuote {
                        swap3 = bQuote
                        swap3Rate = bBid
                        directionTrade3 = "quote_to_base"
                        contract3 = pairB
                    }
                    
                    acquiredCoinT3 = acquiredCoinT2 * swap3Rate
                    calculated = 1
                }
            }
            
            // MARK: Profit Loss ouput
            // Profit and Loss calculations
            let profitLoss = acquiredCoinT3 - startingAmount
            let profitLossPercent = (profitLoss / startingAmount) * 100.0
            
            // Output results
            if profitLossPercent > 0.01 {
                // Trade Description
                let tradeDescription1 = "Step 1: Start with \(swap1) of \(startingAmount) Swap at \(swap1Rate) for \(swap2) acquiring \(acquiredCoinT1)"
                let tradeDescription2 = "Step 2: Swap \(acquiredCoinT1) of \(swap2) at \(swap2Rate) for \(swap3) acquiring \(acquiredCoinT2)"
                let tradeDescription3 = "Step 3: Swap \(acquiredCoinT2) of \(swap3) at \(swap3Rate) for \(swap1) acquiring \(acquiredCoinT3)"
                
                return SurfaceResult(
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
                    profitLossPercent: profitLossPercent,
                    direction: direction,
                    tradeDescription1: tradeDescription1,
                    tradeDescription2: tradeDescription2,
                    tradeDescription3: tradeDescription3
                )
            }
        }
        
        return nil
    }
    
}

// MARK: - Helpers
private extension ArbitrageCalculator {
    
    struct TriangularPrice {
        let pairAAsk: Double
        let pairABid: Double
        let pairBAsk: Double
        let pairBBid: Double
        let pairCAsk: Double
        let pairCBid: Double
    }
    
    func getCurrentPrices(triangular: Triangular) -> TriangularPrice? {
        if let pairAPrice = currentBookTickers?.first(where: { $0.symbol == triangular.pairA }),
           let pairAAsk = Double(pairAPrice.askPrice),
           let pairABid = Double(pairAPrice.bidPrice),
           let pairBPrice = currentBookTickers?.first(where: { $0.symbol == triangular.pairB }),
           let pairBAsk = Double(pairBPrice.askPrice),
           let pairBBid = Double(pairBPrice.bidPrice),
           let pairCPrice = currentBookTickers?.first(where: { $0.symbol == triangular.pairC }),
           let pairCAsk = Double(pairCPrice.askPrice),
           let pairCBid = Double(pairCPrice.bidPrice) {
            return TriangularPrice(pairAAsk: pairAAsk, pairABid: pairABid, pairBAsk: pairBAsk, pairBBid: pairBBid, pairCAsk: pairCAsk, pairCBid: pairCBid)
        } else {
            return nil
        }
    }
    
}
