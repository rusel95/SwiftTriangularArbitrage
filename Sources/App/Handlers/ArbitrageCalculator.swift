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
                print(getCurrentPrices(triangular: triangle))
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
        let minSurfaceRate = 0
        let surfaceDictionary: [String: String] = [:]
    }
    
}

private extension ArbitrageCalculator {
    
    func getCurrentPrices(triangular: [String: String]) -> [String: String]? {
        guard let pairAPrice = currentBookTickers.first(where: { $0.symbol == triangular["pairA"] }),
              let pairBPrice = currentBookTickers.first(where: { $0.symbol == triangular["pairB"] }),
              let pairCPrice = currentBookTickers.first(where: { $0.symbol == triangular["pairC"] }) else {
                return nil
            }
        
        return [
            "pairAAsk": pairAPrice.askPrice,
            "pairABid": pairAPrice.bidPrice,
            "pairBAsk": pairBPrice.askPrice,
            "pairBBid": pairBPrice.bidPrice,
            "pairCAsk": pairCPrice.askPrice,
            "pairCBid": pairCPrice.bidPrice
        ]
    }
    
}
