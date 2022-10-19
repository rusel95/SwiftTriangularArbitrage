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
              forbiddenAssetsToTrade.contains(opportunityToTrade.firstSurfaceResult.swap2) == false else { return }
        
        switch opportunityToTrade.autotradeCicle {
        case .pending:
            guard let firstSymbolDetails = tradeableSymbolsDict[opportunityToTrade.firstSurfaceResult.contract1] else { return }
            
            guard let firstOrderMinNotionalString = firstSymbolDetails.filters.first(where: { $0.filterType == .minNotional })?.minNotional,
                  let firstOrderMinNotional = Double(firstOrderMinNotionalString)
            else {
                opportunityToTrade.autotradeProcessDescription.append("\nError: No min notional")
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
                success: { [weak self] newOrderResponse in
                    guard let newOrderResponse = newOrderResponse else {
                        opportunityToTrade.autotradeProcessDescription.append("\n\nStep 1: No Response")
                        completion(opportunityToTrade)
                        return
                    }
                    
                    opportunityToTrade.autotradeCicle = .firstTradeFinished
                    opportunityToTrade.autotradeProcessDescription.append("\nStep 1: \(newOrderResponse.description)")
                    
                    self?.handleSecondTrade(for: opportunityToTrade,
                                            quantityToExecute: newOrderResponse.executedQty,
                                            startTime: startTime,
                                            completion: completion)
                }, failure: { error in
                    opportunityToTrade.autotradeCicle = .firstTradeError(description: error.localizedDescription)
                    opportunityToTrade.autotradeProcessDescription.append("\n\(error.localizedDescription)")
                    completion(opportunityToTrade)
                }
            )
        default:
            return
        }
    }
    
    private func handleSecondTrade(
        for opportunityToTrade: TriangularOpportunity,
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
            success: { [weak self] newOrderResponse in
                guard let newOrderResponse = newOrderResponse else {
                    opportunityToTrade.autotradeProcessDescription.append("\n\nStep 2: No Response")
                    completion(opportunityToTrade)
                    return
                }
                
                opportunityToTrade.autotradeCicle = .secondTradeFinished
                opportunityToTrade.autotradeProcessDescription.append("\n\nStep 2: \(newOrderResponse.description)")
                
                self?.handleThirdTrade(for: opportunityToTrade,
                                       quantityToExecute: newOrderResponse.executedQty,
                                       startTime: startTime,
                                       completion: completion)
            }, failure: { error in
                opportunityToTrade.autotradeCicle = .secondTradeError(description: error.localizedDescription)
                opportunityToTrade.autotradeProcessDescription.append("\n\(error.localizedDescription)")
                completion(opportunityToTrade)
            }
        )
    }
    
    private func handleThirdTrade(
        for opportunityToTrade: TriangularOpportunity,
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
            success: { newOrderResponse in
                guard let newOrderResponse = newOrderResponse else {
                    opportunityToTrade.autotradeProcessDescription.append("\n\nStep 3: No Response")
                    completion(opportunityToTrade)
                    return
                }
                
                opportunityToTrade.autotradeCicle = .thirdTradeFinished(result: newOrderResponse.description)
                opportunityToTrade.autotradeProcessDescription.append("\n\nStep 3: \(newOrderResponse.description)")
                
                let actualResultingAmount: String
                switch opportunityToTrade.firstSurfaceResult.directionTrade3 {
                case .quoteToBase:
                    actualResultingAmount = newOrderResponse.executedQty
                case .baseToQuote:
                    actualResultingAmount = newOrderResponse.cummulativeQuoteQty
                case .unknown:
                    actualResultingAmount = "ERROR: no side"
                }
                opportunityToTrade.autotradeProcessDescription.append("\n Actual Resulting Amount: \(actualResultingAmount)")
                
                let duration = String(format: "%.4f", CFAbsoluteTimeGetCurrent() - startTime)
                opportunityToTrade.autotradeProcessDescription.append("\nCicle trading time: \(duration)")
                completion(opportunityToTrade)
            }, failure: { error in
                opportunityToTrade.autotradeCicle = .thirdTradeError(description: error.localizedDescription)
                opportunityToTrade.autotradeProcessDescription.append("\n\(error.localizedDescription)")
                completion(opportunityToTrade)
            }
        )
    }
    
}
