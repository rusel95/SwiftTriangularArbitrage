//
//  ArbitrageCalculator.swift
//  
//
//  Created by Ruslan on 30.08.2022.
//

import Foundation

final class ArbitrageCalculator {
    
    static let shared = ArbitrageCalculator()
    
    private init() {}
    
    func getArbitragingOpportunities() {
        
    }
    
    func collectTradables() {
        // Extracting list of coind and prices from Exchange
        BinanceAPIService.shared.getExchangeInfo { symbols in
            guard let symbols = symbols else { return }

            let pairsToCount = symbols[0...100] // TODO: - optimize to get full amout
            
            let start = CFAbsoluteTimeGetCurrent()
            
            var triangularPairsSet: Set<[String: String]> = Set()
            var removeDuplicatesSet: Set<[String]> = Set()
            
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
                                        removeDuplicatesSet.insert(uniqueItem)
                                        let matchDict: [String: String] = [
                                            "a_base": aBase,
                                            "b_base": bBase,
                                            "c_base": cBase,
                                            "a_quote": aQuote,
                                            "b_quote": bQuote,
                                            "c_quote": cQuote,
                                            "pair_a": pairA.symbol,
                                            "pair_b": pairB.symbol,
                                            "pair_c": pairC.symbol,
                                            "combined": uniqueItem.joined(separator: "_")
                                        ]
                                        triangularPairsSet.insert(matchDict)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            let diff = CFAbsoluteTimeGetCurrent() - start
            print(diff, " seconds\n", triangularPairsSet.count)
        }
    }
    
}
