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

            // TODO: - use base/quote instead of this hard String
            let tickersToCount = tickers.filter { $0.symbol.count == 6 }
            
            var triangularPairsList: [BinanceAPIService.BookTicker] = []
            var temoveDuplicatesLst: [BinanceAPIService.BookTicker] = []
            
            // Get Pair A
            // NOTE - should make https://api.binance.com/api/v3/exchangeInfo request to now that
            for tickerA in tickersToCount {
                let pairBoxA = tickerA.symbol.splitStringInHalf()
                let aBase = pairBoxA.firstHalf
                let aQuote = pairBoxA.secondHalf
                
                // Get Pair B
                for tickerB in tickersToCount {
                    let pairBoxB = tickerB.symbol.splitStringInHalf()
                    let bBase = pairBoxB.firstHalf
                    let bQuote = pairBoxB.secondHalf
                    
                    if pairBoxB != pairBoxA {
                        if (pairBoxA.firstHalf == bBase || pairBoxA.secondHalf == bBase) ||
                            (pairBoxA.firstHalf == bQuote || pairBoxA.secondHalf == bQuote) {
                            
                            // Get Pair C
                        }
                    }
                }
            }
        }
    }
    
}

extension String {
   func splitStringInHalf()->(firstHalf:String,secondHalf:String) {
        let words = self.components(separatedBy: " ")
        let halfLength = words.count / 2
        let firstHalf = words[0..<halfLength].joined(separator: " ")
        let secondHalf = words[halfLength..<words.count].joined(separator: " ")
        return (firstHalf:firstHalf,secondHalf:secondHalf)
    }
}
