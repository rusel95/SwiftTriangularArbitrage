//
//  ArbitrageCalculator.swift
//  
//
//  Created by Ruslan on 30.08.2022.
//

import Foundation
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
    
    // MARK: - Properties
    
    static let shared = ArbitrageCalculator()
    
    private var currentTriangulars: Set<[String: String]> = Set()
    private var currentBookTickers: [BinanceAPIService.BookTicker]? = nil {
        didSet {
            guard currentBookTickers?.isEmpty == false else { return }
            
            //            let startTime = CFAbsoluteTimeGetCurrent()
            currentTriangulars.forEach { triangle in
                guard let surfaceResult = calculateSurfaceRate(triangle: triangle) else { return }
                
                print("""
                      \nNew Opportunity:
                      \(surfaceResult.direction) \(surfaceResult.contract1) \(surfaceResult.contract2) \(surfaceResult.contract3)
                      \(surfaceResult.tradeDescription1)
                      \(surfaceResult.tradeDescription2)
                      \(surfaceResult.tradeDescription3)
                      \(String(format: "Profit: %.4f", surfaceResult.profitLossPercent)) %
                      """)
            }
            //            print("!!!!!!! Calculated arbitraging rates for \(currentTriangulars.count) triangulars in \(CFAbsoluteTimeGetCurrent() - startTime) seconds\n")
        }
    }
    
    // MARK: - Init
    
    private init() {
        Jobs.add(interval: .seconds(5)) { [weak self] in
            BinanceAPIService.shared.getAllBookTickers { [weak self] tickers in
                self?.currentBookTickers = tickers ?? []
            }
        }
        Jobs.add(interval: .seconds(30)) { [weak self] in
            BinanceAPIService.shared.getExchangeInfo { [weak self] symbols in
                guard let self = self, let symbols = symbols else { return }
                
                self.currentTriangulars = self.getTriangulars(from: symbols)
            }
        }
    }
    
    // MARK: - Methods
    
    func getArbitragingOpportunities() {
        
    }
    
    // MARK: - Collect Triangles
    func getTriangulars(from symbols: [BinanceAPIService.Symbol]) -> Set<[String: String]> {
        // Extracting list of coind and prices from Exchange
        let pairsToCount = symbols.filter { $0.status == .trading }[0...200] // TODO: - optimize to get full amout
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        var removeDuplicatesSet: Set<[String]> = Set()
        var triangularPairsSet: Set<[String: String]> = Set()
        
        // Get Pair A - Start from A
        // NOTE - should make https://api.binance.com/api/v3/exchangeInfo request to now that
        for pairA in pairsToCount {
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
                                    
                                    if removeDuplicatesSet.contains(uniqueItem) == false {
                                        removeDuplicatesSet.insert(uniqueItem)
                                        let matchDictionary: [String: String] = [
                                            "aBase": aBase,
                                            "bBase": bBase,
                                            "cBase": cBase,
                                            "aQuote": aQuote,
                                            "bQuote": bQuote,
                                            "cQuote": cQuote,
                                            "pairA": pairA.symbol,
                                            "pairB": pairB.symbol,
                                            "pairC": pairC.symbol,
                                            "combined": uniqueItem.joined(separator: "_")
                                        ]
                                        triangularPairsSet.insert(matchDictionary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        print("!!!!!!! Calculated \(triangularPairsSet.count) Triangulars in \(CFAbsoluteTimeGetCurrent() - startTime) seconds\n")
        return triangularPairsSet
    }
    
    
    
    // MARK: - Calculate Surface Rates
    func calculateSurfaceRate(triangle: [String: String]) -> SurfaceResult? {
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
        
        let aBase = triangle["aBase"]!
        let aQuote = triangle["aQuote"]!
        let bBase = triangle["bBase"]!
        let bQuote = triangle["bQuote"]!
        let cBase = triangle["cBase"]!
        let cQuote = triangle["cQuote"]!
        let pairA = triangle["pairA"]!
        let pairB = triangle["pairB"]!
        let pairC = triangle["pairC"]!
        
        guard let prices = getCurrentPrices(triangular: triangle) else { return nil }
        
        let aAsk: Double = prices["pairAAsk"]!
        let aBid: Double = prices["pairABid"]!
        let bAsk: Double = prices["pairBAsk"]!
        let bBid: Double = prices["pairBBid"]!
        let cAsk: Double = prices["pairCAsk"]!
        let cBid: Double = prices["pairCBid"]!
        
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
            if acquiredCoinT3 > startingAmount {
                // Trade Description
                let tradeDescription1 = "Step 1: Start with \(swap1) of \(startingAmount). Swap at \(swap1Rate) for \(swap2) acquiring \(acquiredCoinT1)"
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
    
    func getCurrentPrices(triangular: [String: String]) -> [String: Double]? {
        guard let pairAPrice = currentBookTickers?.first(where: { $0.symbol == triangular["pairA"] }),
              let pairBPrice = currentBookTickers?.first(where: { $0.symbol == triangular["pairB"] }),
              let pairCPrice = currentBookTickers?.first(where: { $0.symbol == triangular["pairC"] }) else {
            return nil
        }
        
        return [
            "pairAAsk": Double(pairAPrice.askPrice)!,
            "pairABid": Double(pairAPrice.bidPrice)!,
            "pairBAsk": Double(pairBPrice.askPrice)!,
            "pairBBid": Double(pairBPrice.bidPrice)!,
            "pairCAsk": Double(pairCPrice.askPrice)!,
            "pairCBid": Double(pairCPrice.bidPrice)!
        ]
    }
    
}
