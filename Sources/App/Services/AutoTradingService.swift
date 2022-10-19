//
//  AutoTradingService.swift
//  
//
//  Created by Ruslan on 12.10.2022.
//

import Jobs
import CoreFoundation

final class AutoTradingService {
    
    static let shared: AutoTradingService = AutoTradingService()
    
    private let allowedAssetsToTrade: Set<String> = Set(arrayLiteral: "BUSD", "USDT", "USDC", "TUSD")
    private let forbiddenAssetsToTrade: Set<String> = Set(arrayLiteral: "RUB")
    
    private var tradeableSymbolsDict: [String: BinanceAPIService.Symbol] = [:]
    
    private init() {
        Jobs.add(interval: .seconds(1800)) { [weak self] in
            BinanceAPIService.shared.getExchangeInfo { [weak self] symbols in
                guard let symbols = symbols else { return }
                
                let tradeableSymbols = symbols.filter { $0.status == .trading && $0.isSpotTradingAllowed }
                
                self?.tradeableSymbolsDict = tradeableSymbols.toDictionary(with: { $0.symbol })
            }
        }
    }
    
    func handle(
        triangularOpportunitiesDict: [String: TriangularOpportunity],
        for userInfo: UserInfo,
        completion: @escaping(_ finishedTriangularOpportunity: TriangularOpportunity) -> Void
    ) {
        // NOTE: - Trade only some first opportunity - only 1 opportunity at a time
        guard let opportunityToTrade = triangularOpportunitiesDict.first(where: { allowedAssetsToTrade.contains($0.value.firstSurfaceResult.swap0) })?.value,
              forbiddenAssetsToTrade.contains(opportunityToTrade.firstSurfaceResult.swap0) == false,
              forbiddenAssetsToTrade.contains(opportunityToTrade.firstSurfaceResult.swap1) == false,
              forbiddenAssetsToTrade.contains(opportunityToTrade.firstSurfaceResult.swap2) == false,
              opportunityToTrade.duration >= 3
        else { return }
        
        switch opportunityToTrade.autotradeCicle {
        case .pending:
            guard let firstSymbolDetails = tradeableSymbolsDict[opportunityToTrade.firstSurfaceResult.contract1] else { return }
            
            guard let firstOrderMinNotionalString = firstSymbolDetails.filters.first(where: { $0.filterType == .minNotional })?.minNotional,
                  let firstOrderMinNotional = Double(firstOrderMinNotionalString)
            else {
                opportunityToTrade.autotradeLog.append("\nError: No min notional")
                completion(opportunityToTrade)
                return
            }
            
            let startTime = CFAbsoluteTimeGetCurrent()
            opportunityToTrade.autotradeCicle = .firstTradeStarted
            
            BinanceAPIService.shared.newOrder(
                symbol: opportunityToTrade.firstSurfaceResult.contract1,
                side: opportunityToTrade.firstSurfaceResult.directionTrade1,
                type: .market,
                quantity: String(firstOrderMinNotional * 1.5),
                quoteOrderQty: String(firstOrderMinNotional * 1.5),
                newOrderRespType: .full,
                success: { [weak self] firstOrderResponse in
                    guard let firstOrderResponse = firstOrderResponse else {
                        opportunityToTrade.autotradeLog.append("\n\nStep 1: No Response")
                        completion(opportunityToTrade)
                        return
                    }
                    
                    let usedCapital: Double
                    switch opportunityToTrade.firstSurfaceResult.directionTrade3 {
                    case .quoteToBase:
                        usedCapital = Double(firstOrderResponse.executedQty) ?? 0.0
                    case .baseToQuote:
                        usedCapital = Double(firstOrderResponse.cummulativeQuoteQty) ?? 0.0
                    case .unknown:
                        usedCapital = 0
                    }
                    opportunityToTrade.autotradeCicle = .firstTradeFinished
                    opportunityToTrade.autotradeLog.append("\nStep 1: \(firstOrderResponse.description)")
                    
                    // TODO: - make quantity to execute be consistent with LOT_SIZE - it should be rounded
                    self?.handleSecondTrade(for: opportunityToTrade,
                                            usedCapital: usedCapital,
                                            quantityToExecute: firstOrderResponse.executedQty,
                                            startTime: startTime,
                                            completion: completion)
                }, failure: { error in
                    let errorDescription: String
                    if let binanceError = error as? BinanceAPIService.BinanceError {
                        errorDescription = binanceError.description
                    } else {
                        errorDescription = error.localizedDescription
                    }
                    opportunityToTrade.autotradeCicle = .firstTradeError(description: errorDescription)
                    opportunityToTrade.autotradeLog.append("\n\n Step 1:\(errorDescription)")
                    completion(opportunityToTrade)
                }
            )
        default:
            return
        }
    }
    
    private func handleSecondTrade(
        for opportunityToTrade: TriangularOpportunity,
        usedCapital: Double,
        quantityToExecute: String,
        startTime: CFAbsoluteTime,
        completion: @escaping(_ finishedTriangularOpportunity: TriangularOpportunity) -> Void
    ) {
        opportunityToTrade.autotradeCicle = .secondTradeStarted
        
        
        BinanceAPIService.shared.newOrder(
            symbol: opportunityToTrade.firstSurfaceResult.contract2,
            side: opportunityToTrade.firstSurfaceResult.directionTrade2,
            type: .market,
            quantity: quantityToExecute,
            quoteOrderQty: quantityToExecute,
            newOrderRespType: .full,
            success: { [weak self] secondOrderResponse in
                guard let secondOrderResponse = secondOrderResponse else {
                    opportunityToTrade.autotradeLog.append("\n\nStep 2: No Response")
                    completion(opportunityToTrade)
                    return
                }
                
                opportunityToTrade.autotradeCicle = .secondTradeFinished
                opportunityToTrade.autotradeLog.append("\n\nStep 2: \(secondOrderResponse.description)")
                
                // TODO: - make quantity to execute be consistent with LOT_SIZE - it should be rounded
                self?.handleThirdTrade(for: opportunityToTrade,
                                       usedCapital: usedCapital,
                                       quantityToExecute: secondOrderResponse.executedQty,
                                       startTime: startTime,
                                       completion: completion)
            }, failure: { error in
                let errorDescription: String
                if let binanceError = error as? BinanceAPIService.BinanceError {
                    errorDescription = binanceError.description
                } else {
                    errorDescription = error.localizedDescription
                }
                opportunityToTrade.autotradeCicle = .secondTradeError(description: errorDescription)
                opportunityToTrade.autotradeLog.append("\n\n Step 2:\(errorDescription)")
                completion(opportunityToTrade)
            }
        )
    }
    
    private func handleThirdTrade(
        for opportunityToTrade: TriangularOpportunity,
        usedCapital: Double,
        quantityToExecute: String,
        startTime: CFAbsoluteTime,
        completion: @escaping(_ finishedTriangularOpportunity: TriangularOpportunity) -> Void
    ) {
        opportunityToTrade.autotradeCicle = .thirdTradeStarted
        
        BinanceAPIService.shared.newOrder(
            symbol: opportunityToTrade.firstSurfaceResult.contract3,
            side: opportunityToTrade.firstSurfaceResult.directionTrade3,
            type: .market,
            quantity: quantityToExecute,
            quoteOrderQty: quantityToExecute,
            newOrderRespType: .full,
            success: { thirdOrderResponse in
                guard let thirdOrderResponse = thirdOrderResponse else {
                    opportunityToTrade.autotradeLog.append("\n\nStep 3: No Response")
                    completion(opportunityToTrade)
                    return
                }
                
                opportunityToTrade.autotradeCicle = .thirdTradeFinished(result: thirdOrderResponse.description)
                opportunityToTrade.autotradeLog.append("\n\nStep 3: \(thirdOrderResponse.description)")
                
                let duration = String(format: "%.4f", CFAbsoluteTimeGetCurrent() - startTime)
                opportunityToTrade.autotradeLog.append("\n\nCicle trading time: \(duration)s")
                
                let actualResultingAmount: Double
                switch opportunityToTrade.firstSurfaceResult.directionTrade3 {
                case .quoteToBase:
                    actualResultingAmount = Double(thirdOrderResponse.executedQty) ?? 0.0
                case .baseToQuote:
                    actualResultingAmount = Double(thirdOrderResponse.cummulativeQuoteQty) ?? 0.0
                case .unknown:
                    actualResultingAmount = 0
                }
                opportunityToTrade.autotradeLog.append("\nUsed Capital: \(usedCapital) | Actual Resulting Amount: \(actualResultingAmount)")
                opportunityToTrade.autotradeLog.append("\nProfit: \(((actualResultingAmount - usedCapital) / usedCapital).string())%")
                
                completion(opportunityToTrade)
            }, failure: { error in
                let errorDescription: String
                if let binanceError = error as? BinanceAPIService.BinanceError {
                    errorDescription = binanceError.description
                } else {
                    errorDescription = error.localizedDescription
                }
                opportunityToTrade.autotradeCicle = .thirdTradeError(description: errorDescription)
                opportunityToTrade.autotradeLog.append("\n\n Step 3:\(errorDescription)")
                completion(opportunityToTrade)
            }
        )
    }
    
}
