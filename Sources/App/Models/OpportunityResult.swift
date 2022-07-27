//
//  OpportunityResult.swift
//  
//
//  Created by Ruslan Popesku on 27.07.2022.
//

import Foundation

struct OpportunityResult {
    
    let opportunity: Opportunity
    let priceInfo: PricesInfo
    
    var finalSellPrice: Double? {
        guard let sellCommission = opportunity.sellCommission else { return nil }
        
        return priceInfo.possibleSellPrice - (priceInfo.possibleSellPrice * (sellCommission) / 100.0)
    }
    
    var finalBuyPrice: Double? {
        guard let buyCommission = opportunity.buyCommission else { return nil }
        
        return priceInfo.possibleBuyPrice + (priceInfo.possibleBuyPrice * (buyCommission) / 100.0)
    }
}
