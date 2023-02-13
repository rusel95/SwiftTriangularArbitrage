//
//  File.swift
//  
//
//  Created by Ruslan on 19.01.2023.
//

import Foundation

struct TriangularsCalculator {
    
    private static let stableAssets: Set<String> = Set(arrayLiteral: "BUSD", "USDT", "USDC", "TUSD")
    private static let tradeableAssets: Set<String> = Set(arrayLiteral: "BUSD", "USDT", "USDC", "TUSD", "BTC", "ETH", "BNB", "UAH")
    
    static func getTradeableAssetsTriangulars(from tradeableSymbols: [TradeableSymbol]) -> [Triangular] {
        var triangulars: Set<Triangular> = Set()
        
        // Get Pair A - Start from A
        for pairA in tradeableSymbols {
            let aBase: String = pairA.baseAsset
            let aQuote: String = pairA.quoteAsset
            
            guard tradeableAssets.contains(aBase) || tradeableAssets.contains(aQuote) else { break }
            
            // Get Pair B - Find B pair where one coint matched
            for pairB in tradeableSymbols {
                let bBase: String = pairB.baseAsset
                let bQuote: String = pairB.quoteAsset
                
                if pairB.symbol != pairA.symbol {
                    if (aBase == bBase || aQuote == bBase) || (aBase == bQuote || aQuote == bQuote) {
                        
                        // Get Pair C - Find C pair where base and quote exist in A and B configurations
                        for pairC in tradeableSymbols {
                            let cBase: String = pairC.baseAsset
                            let cQuote: String = pairC.quoteAsset
                            
                            guard tradeableAssets.contains(cBase) || tradeableAssets.contains(cQuote) else { break }
                            
                            // Count the number of matching C items
                            if pairC.symbol != pairA.symbol && pairC.symbol != pairB.symbol {
                                let pairBox: [String] = [aBase, aQuote, bBase, bQuote, cBase, cQuote]
                                
                                let cBaseCount = pairBox.filter { $0 == cBase }.count
                                let cQuoteCount = pairBox.filter { $0 == cQuote }.count
                                
                                // Determining Triangular Match
                                if cBaseCount == 2 && cQuoteCount == 2 && cBase != cQuote {
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
            
        return Array(triangulars)
    }
    
    static func getTriangularsInfo(
        for mode: Mode,
        from tradeableSymbols: [TradeableSymbol]
    ) -> [Triangular] {
        var triangulars: Set<Triangular> = Set()
        
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
                        if (aBase == bBase || aQuote == bBase) || (aBase == bQuote || aQuote == bQuote) {
                            
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
        
        return Array(triangulars)
    }
    
}
