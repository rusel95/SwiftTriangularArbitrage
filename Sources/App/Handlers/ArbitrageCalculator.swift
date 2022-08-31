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
        BinanceAPIService.shared.getAllBookTickers { tickers in
            guard let tickers = tickers else { return }

            let pairsToCount = tickers
                .filter { $0.symbol.count == 6 } // TODO: - use base/quote instead of this hard String
                .map { $0.symbol }[0...100] // TODO: - optimize to get full amout
            
            let start = CFAbsoluteTimeGetCurrent()
            
            var triangularPairsSet: Set<[String: String]> = Set()
            var removeDuplicatesSet: Set<[String]> = Set()
            
            // Get Pair A - Start from A
            // NOTE - should make https://api.binance.com/api/v3/exchangeInfo request to now that
            for pairA in pairsToCount {
                let pairASplit = pairA.splitStringInHalf()
                let aBase = pairASplit.firstHalf
                let aQuote = pairASplit.secondHalf
                
                // Get Pair B - Find B pair where one coint matched
                for pairB in pairsToCount {
                    let pairBSplit = pairB.splitStringInHalf()
                    let bBase = pairBSplit.firstHalf
                    let bQuote = pairBSplit.secondHalf
                    
                    if pairBSplit != pairASplit {
                        if (pairASplit.firstHalf == bBase || pairASplit.secondHalf == bBase) ||
                            (pairASplit.firstHalf == bQuote || pairASplit.secondHalf == bQuote) {
                            
                            // Get Pair C - Find C pair where base and quote exist in A and B configurations
                            for pairC in pairsToCount {
                                let pairCSplit = pairC.splitStringInHalf()
                                let cBase = pairCSplit.firstHalf
                                let cQuote = pairCSplit.secondHalf
                                
                                // Count the number of matching C items
                                if pairCSplit != pairASplit && pairCSplit != pairBSplit {
                                    let combineAll = [pairA, pairB, pairC]
                                    let pairBox = [aBase, aQuote, bBase, bQuote, cBase, cQuote]
                                    
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
                                            "pair_a": pairA,
                                            "pair_b": pairB,
                                            "pair_c": pairC,
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

extension String {
    
   func splitStringInHalf() -> (firstHalf: String, secondHalf: String) {
        let firstHalf = self.prefix(3)
        let secondHalf = self.suffix(3)
        return (firstHalf: String(firstHalf), secondHalf: String(secondHalf))
    }
    
}
