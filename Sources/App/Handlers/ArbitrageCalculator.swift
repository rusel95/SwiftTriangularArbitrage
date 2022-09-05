//
//  ArbitrageCalculator.swift
//  
//
//  Created by Ruslan on 30.08.2022.
//

import Foundation
import Jobs

final class ArbitrageCalculator {
    
    // MARK: - Enums
    
    
    // MARK: - Properties
    
    static let shared = ArbitrageCalculator()
    
    private var currentTriangulars: Set<[String: String]> = Set()
    private var currentBookTickers: [BinanceAPIService.BookTicker] = [] {
        didSet {
            currentTriangulars.forEach { triangle in
                calculateSurfaceRate(triangle: triangle)
            }
        }
    }
    
    // MARK: - Init
    
    private init() {
        print("!!!!!! ArbitrageCalculator init")
        Jobs.add(interval: .seconds(5)) { [weak self] in
            BinanceAPIService.shared.getAllBookTickers { [weak self] tickers in
                print("!!!!! Current amount tickers: \(tickers?.count ?? 0)")
                self?.currentBookTickers = tickers ?? []
            }
        }
        Jobs.add(interval: .seconds(30)) { [weak self] in
            self?.collectTriangularPairs { [weak self] triangulars in
                self?.currentTriangulars = triangulars
            }
        }
    }
    
    // MARK: - Methods
    
    func getArbitragingOpportunities() {
        
    }
    
    // Step 0 and 1
    func collectTriangularPairs(completion: @escaping(Set<[String: String]>) -> Void) {
        // Extracting list of coind and prices from Exchange
        BinanceAPIService.shared.getExchangeInfo { symbols in
            guard let symbols = symbols else { return }

            let pairsToCount = symbols.filter { $0.status == .trading }[0...100] // TODO: - optimize to get full amout
            
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
            
            let diffTime = CFAbsoluteTimeGetCurrent() - startTime
            print("!!!!!!! Calculated \(triangularPairsSet.count) Triangulars in \(diffTime) seconds\n")
            completion(triangularPairsSet)
        }
    }
    
   
    
    // Calculate Surface Rate of arbitrage opportunity
    func calculateSurfaceRate(triangle: [String: String]) {
        // Set Variables
        let startingAmount: Double = 1.0
        let minSurfaceRate = 0
        var surfaceDictionary: [String: String] = [:]
        
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
        
        guard let prices = getCurrentPrices(triangular: triangle) else { return }
        
        let aAsk: Double = prices["pairAAsk"]!
        let aBid: Double = prices["pairABid"]!
        let bAsk: Double = prices["pairBAsk"]!
        let bBid: Double = prices["pairBBid"]!
        let cAsk: Double = prices["pairCAsk"]!
        let cBid: Double = prices["pairCBid"]!
        
        // Set direction and loop through
        let directionList = ["forward", "reverse"]
        for direction in directionList {
            // Set additional variables for swap information
            var swap1 = ""
            var swap2 = ""
            var swap3 = ""
            var swap1Rate: Double = 0.0
            var swap2Rate: Double = 0.0
            var swap3Rate: Double = 0.0
            var directionTrade1 = ""
            
            // If we are swapping the coin on the left (Base) to the right (Quote) then * (1 / Ask)
            // If we are swapping the coin on the right (Quite) to the left (Base) then * Bid
            
            // Assume starting aBase and swapping for aQuote
            
            if direction == "forward" {
                swap1 = aBase
                swap2 = aQuote
                swap1Rate = 1.0 / aAsk
                directionTrade1 = "base_to_quote"
            } else {
                swap1 = aQuote
                swap2 = aBase
                swap1Rate = aBid
                directionTrade1 = "quote_to_base"
            }
            // Place first trade
            contract1 = pairA
            acquiredCoinT1 = startingAmount * swap1Rate
            
            print(direction, pairA, startingAmount, acquiredCoinT1)
            
            /*
             FORWARD
             */
            // 1.0 Check if aQoute (acquired_coun) batches bQuote
            if direction == "forward" {
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
            
            // 2.0 Check if aQoute (acquired_coun) batches bBase
            if direction == "forward" {
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
            
        }
    }
    
}

private extension ArbitrageCalculator {
    
    func getCurrentPrices(triangular: [String: String]) -> [String: Double]? {
        guard let pairAPrice = currentBookTickers.first(where: { $0.symbol == triangular["pairA"] }),
              let pairBPrice = currentBookTickers.first(where: { $0.symbol == triangular["pairB"] }),
              let pairCPrice = currentBookTickers.first(where: { $0.symbol == triangular["pairC"] }) else {
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
