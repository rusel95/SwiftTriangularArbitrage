//
//  RateCalculator.swift
//  
//
//  Created by Ruslan on 06.02.2023.
//

import Foundation
import Logging

struct RateCalculator {
    
    // TODO: - add symbolsWithoutComissions for different Stocks
    private static let binanceSymbolsWithoutComissions: Set<String> = Set(arrayLiteral: "BTCAUD", "BTCBIDR", "BTCBRL", "BTCBUSD", "BTCEUR", "BTCGBP", "BTCTRY", "BTCTUSD", "BTCUAH", "BTCUSDC", "BTCUSDP", "BTCUSDT")
    
    private static let stableAssets: Set<String> = Set(arrayLiteral: "BUSD", "USDT", "USDC", "TUSD", "USD")
    
    private static let logger = Logger(label: "logger.artitrage.triangular")
    
    static func getSurfaceResults(
        stockExchange: StockExchange,
        mode: Mode,
        triangulars: [Triangular],
        bookTickersDict: [String: BookTicker]
    ) -> [SurfaceResult] {
        let valuableSurfaceResults = triangulars
            .compactMap { triangular in
                RateCalculator.calculateSurfaceRate(
                    bookTickersDict: bookTickersDict,
                    mode: mode,
                    stockExchange: stockExchange,
                    triangular: triangular
                )
            }
            .sorted(by: { $0.profitPercent > $1.profitPercent })
        
        return Array(valuableSurfaceResults)
    }
    
    static func getActualTriangularOpportunitiesDict(
        from surfaceResults: [SurfaceResult],
        currentOpportunities: [String: TriangularOpportunity],
        profitPercent: Double
    ) -> [String: TriangularOpportunity] {
        var updatedOpportunities: [String: TriangularOpportunity] = currentOpportunities
        
        let extraResults = surfaceResults
            .filter { $0.profitPercent >= profitPercent }
            .sorted(by: { $0.profitPercent > $1.profitPercent })
        
        // Add/Update
        extraResults.forEach { surfaceResult in
            if let currentOpportunity = updatedOpportunities[surfaceResult.contractsDescription] {
                currentOpportunity.surfaceResults.append(surfaceResult)
            } else {
                updatedOpportunities[surfaceResult.contractsDescription] = TriangularOpportunity(
                    contractsDescription: surfaceResult.contractsDescription,
                    firstSurfaceResult: surfaceResult,
                    updateMessageId: nil
                )
            }
        }
        
        // Remove opportunities, which became old
        return updatedOpportunities.filter {
            Double(Date().timeIntervalSince($0.value.latestUpdateDate)) < 15
        }
    }
    
    // MARK: - Surface Rate
    
    static func calculateSurfaceRate(
        bookTickersDict: [String: BookTicker],
        mode: Mode,
        stockExchange: StockExchange,
        triangular: Triangular
    ) -> SurfaceResult? {
        let startingAmount: Double = 1.0
        
        var contract1 = ""
        var contract2 = ""
        var contract3 = ""
        
        var directionTrade1: OrderSide = .unknown
        var directionTrade2: OrderSide = .unknown
        var directionTrade3: OrderSide = .unknown
        
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
        
        let pairAComissionMultipler = getCommissionMultipler(symbol: pairA, stockExchange: stockExchange)
        let pairBComissionMultipler = getCommissionMultipler(symbol: pairB, stockExchange: stockExchange)
        let pairCComissionMultipler = getCommissionMultipler(symbol: pairC, stockExchange: stockExchange)
        
        guard let pairABookTicker = bookTickersDict[triangular.pairA] ?? bookTickersDict["\(aBase)\(aQuote)"],
              let aAsk = Double(pairABookTicker.askPrice),
              let aBid = Double(pairABookTicker.bidPrice),
              let pairBBookTicker = bookTickersDict[triangular.pairB] ?? bookTickersDict["\(bBase)\(bQuote)"],
              let bAsk = Double(pairBBookTicker.askPrice),
              let bBid = Double(pairBBookTicker.bidPrice),
              let pairCBookTicker = bookTickersDict[triangular.pairC] ?? bookTickersDict["\(cBase)\(cQuote)"],
              let cAsk = Double(pairCBookTicker.askPrice),
              let cBid = Double(pairCBookTicker.bidPrice) else {
            RateCalculator.logger.critical("No prices for \(triangular)")
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
                directionTrade1 = .baseToQuote
            case .reverse:
                swap0 = aQuote
                swap1 = aBase
                swap1Rate = 1.0 / aAsk
                directionTrade1 = .quoteToBase
            }
            
            switch mode {
            case .standart: break
            case .stable:
                if RateCalculator.stableAssets.contains(swap0) {
                    break
                } else {
                    return nil
                }
            }
            
            // Place first trade
            contract1 = pairA
            acquiredCoinT1 = startingAmount * swap1Rate * pairAComissionMultipler
            
            /* FORWARD */
            // MARK: SCENARIO 1
            // Check if aQoute (acquired coin) matches bQuote
            if direction == .forward {
                if aQuote == bQuote {
                    swap2Rate = 1.0 / bAsk
                    acquiredCoinT2 = acquiredCoinT1 * swap2Rate * pairBComissionMultipler
                    directionTrade2 = .quoteToBase
                    contract2 = pairB
                    
                    // if bBase (aquiredCoin) mathces cBase
                    if bBase == cBase {
                        swap2 = cBase
                        swap3 = cQuote
                        swap3Rate = cBid
                        directionTrade3 = .baseToQuote
                        contract3 = pairC
                    }
                    
                    // if bBase (aquired coin) mathces cQuote
                    if bBase == cQuote {
                        swap2 = cQuote
                        swap3 = cBase
                        swap3Rate = 1.0 / cAsk
                        directionTrade3 = .quoteToBase
                        contract3 = pairC
                    }
                    
                    acquiredCoinT3 = acquiredCoinT2 * swap3Rate * pairAComissionMultipler
                }
                
                // MARK: SCENARIO 2
                // Check if aQoute (acquired coin) matches bBase
                else if aQuote == bBase {
                    swap2Rate = bBid
                    acquiredCoinT2 = acquiredCoinT1 * swap2Rate * pairBComissionMultipler
                    directionTrade2 = .baseToQuote
                    contract2 = pairB
                    
                    // if bQuote (aquired coin) mathces cBase
                    if bQuote == cBase {
                        swap2 = cBase
                        swap3 = cQuote
                        swap3Rate = cBid
                        directionTrade3 = .baseToQuote
                        contract3 = pairC
                    }
                    
                    // if bQoute (aquired coin) mathces cQuote
                    if bQuote == cQuote {
                        swap2 = cQuote
                        swap3 = cBase
                        swap3Rate = 1.0 / cAsk
                        directionTrade3 = .quoteToBase
                        contract3 = pairC
                    }
                    
                    acquiredCoinT3 = acquiredCoinT2 * swap3Rate * pairCComissionMultipler
                }
                // MARK: SCENARIO 3
                // Check if aQoute (aquired coin) matches cQuote
                else if aQuote == cQuote {
                    swap2Rate = 1.0 / cAsk
                    acquiredCoinT2 = acquiredCoinT1 * swap2Rate * pairCComissionMultipler
                    directionTrade2 = .quoteToBase
                    contract2 = pairC
                    
                    // if cBase (aquired coin) mathces bBase
                    if cBase == bBase {
                        swap2 = bBase
                        swap3 = bQuote
                        swap3Rate = bBid
                        directionTrade3 = .baseToQuote
                        contract3 = pairB
                    }
                    
                    // if cBase (aquired coin) mathces bQuote
                    if cBase == bQuote {
                        swap2 = bQuote
                        swap3 = bBase
                        swap3Rate = 1.0 / bAsk
                        directionTrade3 = .quoteToBase
                        contract3 = pairB
                    }
                    
                    acquiredCoinT3 = acquiredCoinT2 * swap3Rate * pairCComissionMultipler
                }
                // MARK: SCENARIO 4
                // Check if aQoute (aquired coin) matches cBase
                else if aQuote == cBase {
                    swap2Rate = cBid
                    acquiredCoinT2 = acquiredCoinT1 * swap2Rate * pairCComissionMultipler
                    directionTrade2 = .baseToQuote
                    contract2 = pairC
                    
                    // if cQuote (aquired coin) mathces bBase
                    if cQuote == bBase {
                        swap2 = bBase
                        swap3 = bQuote
                        swap3Rate = bBid
                        directionTrade3 = .baseToQuote
                        contract3 = pairB
                    }
                    
                    // if cQuote (aquired coin) mathces bQuote
                    if cQuote == bQuote {
                        swap2 = bQuote
                        swap3 = bBase
                        swap3Rate = 1.0 / bAsk
                        directionTrade3 = .quoteToBase
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
                    directionTrade2 = .quoteToBase
                    contract2 = pairB
                    
                    // if bBase (aquired coin) mathces cBase
                    if bBase == cBase {
                        swap2 = cBase
                        swap3 = cQuote
                        swap3Rate = cBid
                        directionTrade3 = .baseToQuote
                        contract3 = pairC
                    }
                    
                    // if bBase (aquired coin) mathces cQuote
                    if bBase == cQuote {
                        swap2 = cQuote
                        swap3 = cBase
                        swap3Rate = 1.0 / cAsk
                        directionTrade3 = .quoteToBase
                        contract3 = pairC
                    }
                    
                    acquiredCoinT3 = acquiredCoinT2 * swap3Rate * pairCComissionMultipler
                }
                // MARK: SCENARIO 6
                // Check if aBase (aquired coin) matches bBase
                else if aBase == bBase {
                    swap2Rate = bBid
                    acquiredCoinT2 = acquiredCoinT1 * swap2Rate * pairBComissionMultipler
                    directionTrade2 = .baseToQuote
                    contract2 = pairB
                    
                    // if bQuote (aquired coin) mathces cBase
                    if bQuote == cBase {
                        swap2 = cBase
                        swap3 = cQuote
                        swap3Rate = cBid
                        directionTrade3 = .baseToQuote
                        contract3 = pairC
                    }
                    
                    // if bQoute (aquired coin) mathces cQuote
                    if bQuote == cQuote {
                        swap2 = cQuote
                        swap3 = cBase
                        swap3Rate = 1.0 / cAsk
                        directionTrade3 = .quoteToBase
                        contract3 = pairC
                    }
                    
                    acquiredCoinT3 = acquiredCoinT2 * swap3Rate * pairCComissionMultipler
                }
                // MARK: SCENARIO 7
                // Check if aBase (aquired coin) matches cQuote
                else if aBase == cQuote {
                    swap2Rate = 1.0 / cAsk
                    acquiredCoinT2 = acquiredCoinT1 * swap2Rate * pairCComissionMultipler
                    directionTrade2 = .quoteToBase
                    contract2 = pairC
                    
                    // if cBase (aquired coin) mathces bBase
                    if cBase == bBase {
                        swap2 = bBase
                        swap3 = bQuote
                        swap3Rate = bBid
                        directionTrade3 = .baseToQuote
                        contract3 = pairB
                    }
                    
                    // if bBase (aquired coin) mathces bQuote
                    if cBase == bQuote {
                        swap2 = bQuote
                        swap3 = bBase
                        swap3Rate = 1.0 / bAsk
                        directionTrade3 = .quoteToBase
                        contract3 = pairB
                    }
                    
                    acquiredCoinT3 = acquiredCoinT2 * swap3Rate * pairBComissionMultipler
                }
                // MARK: SCENARIO 8
                // Check if aBase (aquired coin) atches cBase
                else if aBase == cBase {
                    swap2Rate = cBid
                    acquiredCoinT2 = acquiredCoinT1 * swap2Rate * pairCComissionMultipler
                    directionTrade2 = .baseToQuote
                    contract2 = pairC
                    
                    // if cQuote (aquired coin) mathces bBase
                    if cQuote == bBase {
                        swap2 = bBase
                        swap3 = bQuote
                        swap3Rate = bBid
                        directionTrade3 = .baseToQuote
                        contract3 = pairB
                    }
                    
                    // if cQuote (aquired coin) mathces bQuote
                    if cQuote == bQuote {
                        swap2 = bQuote
                        swap3 = bBase
                        swap3Rate = 1.0 / bAsk
                        directionTrade3 = .quoteToBase
                        contract3 = pairB
                    }
                    
                    acquiredCoinT3 = acquiredCoinT2 * swap3Rate * pairBComissionMultipler
                }
            }
            
            // MARK: Profit Loss ouput
            let profit = acquiredCoinT3 - startingAmount
            let profitPercent = (profit / startingAmount) * 100.0
            
            // Output results
            if profitPercent > -0.2 {
                let contract1AvailableQuantity: Double? = directionTrade1 == .baseToQuote ? Double(pairABookTicker.bidQty)! : (Double(pairABookTicker.askQty)! / swap1Rate)
                let contract2AvailableQuantity: Double? = directionTrade2 == .baseToQuote ? Double(pairBBookTicker.bidQty)! : (Double(pairBBookTicker.askQty)! / swap2Rate)
                let contract3AvailableQuantity: Double? = directionTrade3 == .baseToQuote ? Double(pairCBookTicker.bidQty)! : (Double(pairCBookTicker.askQty)! / swap3Rate)
                
                return SurfaceResult(
                    modeDescrion: mode.description,
                    swap0: swap0,
                    swap1: swap1,
                    swap2: swap2,
                    swap3: swap3,
                    contract1: contract1,
                    contract2: contract2,
                    contract3: contract3,
                    contract1AvailableQuantity: contract1AvailableQuantity,
                    contract2AvailableQuantity: contract2AvailableQuantity,
                    contract3AvailableQuantity: contract3AvailableQuantity,
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
    
    static func getCommissionMultipler(symbol: String, stockExchange: StockExchange) -> Double {
        let comissionPercent: Double
        switch stockExchange {
        case .binance:
            comissionPercent = RateCalculator.binanceSymbolsWithoutComissions.contains(symbol) ? 0 : 0.075
        case .bybit:
            comissionPercent = 0.0
        case .huobi:
            comissionPercent = 0.15
        case .exmo:
            comissionPercent = 0.3
        case .kucoin:
            comissionPercent = 0.1
        case .kraken:
            comissionPercent = 0.26
        case .whitebit:
            comissionPercent = 0.1
        case .gateio:
            comissionPercent = 0.2
        }
        return 1.0 - comissionPercent / 100.0
    }
    
}
