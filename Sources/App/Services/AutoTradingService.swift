//
//  AutoTradingService.swift
//  
//
//  Created by Ruslan on 12.10.2022.
//

import Foundation

final class AutoTradingService {
    
    static let shared: AutoTradingService = AutoTradingService()
    
    private let stables: Set<String> = Set(arrayLiteral: "BUSD", "USDT", "USDC", "TUSD")
    
    private init() {}
    
    
    private let stableCoinsQuantity = 11.0
    
    func handle(triangularOpportunitiesDict: [String: TriangularOpportunity], for userInfo: UserInfo) {
        guard let opportunityToTrade = triangularOpportunitiesDict.first(where: { stables.contains($0.value.firstSurfaceResult.swap0) })?.value else { return }
        
        switch opportunityToTrade.autotradeCicle {
        case .pending:
            opportunityToTrade.autotradeCicle = .firstTradeStarted
            
            let firstOrderQuantity = String(format: "%.8f", Double(stableCoinsQuantity * opportunityToTrade.firstSurfaceResult.swap1Rate))
            BinanceAPIService.shared.newOrder(
                symbol: opportunityToTrade.firstSurfaceResult.contract1,
                side: opportunityToTrade.firstSurfaceResult.directionTrade1,
                type: .market,
                quantity: firstOrderQuantity, // we will try to aquire only smallest number of elements
                newOrderRespType: .full,
                success: { [weak self] newOrderResponse in
                    opportunityToTrade.autotradeCicle = .firstTradeFinished
                    self?.handleThirdTrade(for: opportunityToTrade)
                }, failure: { error in
                    print(error.localizedDescription)
                    opportunityToTrade.autotradeCicle = .firstTradeError(description: error.localizedDescription)
                }
            )
        default:
            return
        }
    }
    
    private func handleSecondTrade(for opportunityToTrade: TriangularOpportunity) {
        opportunityToTrade.autotradeCicle = .secondTradeStarted
        
        BinanceAPIService.shared.newOrder(
            symbol: opportunityToTrade.firstSurfaceResult.contract2,
            side: opportunityToTrade.firstSurfaceResult.directionTrade2,
            type: .market,
            quantity: String(stableCoinsQuantity * opportunityToTrade.firstSurfaceResult.acquiredCoinT1),
            newOrderRespType: .full,
            success: { [weak self] newOrderResponse in
                opportunityToTrade.autotradeCicle = .secondTradeFinished
                self?.handleThirdTrade(for: opportunityToTrade)
            }, failure: { error in
                opportunityToTrade.autotradeCicle = .secondTradeError(description: error.localizedDescription)
            }
        )
    }
    
    private func handleThirdTrade(for opportunityToTrade: TriangularOpportunity) {
        opportunityToTrade.autotradeCicle = .thirdTradeStarted
        
        BinanceAPIService.shared.newOrder(
            symbol: opportunityToTrade.firstSurfaceResult.contract3,
            side: opportunityToTrade.firstSurfaceResult.directionTrade3,
            type: .market,
            quantity: String(stableCoinsQuantity * opportunityToTrade.firstSurfaceResult.acquiredCoinT2),
            newOrderRespType: .full,
            success: { newOrderResponse in
                opportunityToTrade.autotradeCicle = .thirdTradeFinished(result: newOrderResponse.debugDescription)
            }, failure: { error in
                opportunityToTrade.autotradeCicle = .thirdTradeError(description: error.localizedDescription)
            }
        )
    }
    
}
