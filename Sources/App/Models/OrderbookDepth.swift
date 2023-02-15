//
//  OrderbookDepth.swift
//  
//
//  Created by Ruslan on 23.11.2022.
//

import Foundation

struct TriangularOpportunityDepth {
    let pairADepth: OrderbookDepth
    let pairBDepth: OrderbookDepth
    let pairCDepth: OrderbookDepth
}

struct OrderbookDepth: Codable {

    typealias MarketOrder = (price: Double, quantity: Double)
    
    let lastUpdateId: UInt
    let asks: [[String]]
    let bids: [[String]]
    
    var bidMarketOrders: [MarketOrder] {
        bids.map { MarketOrder(price: Double($0.first ?? "") ?? 0.0, quantity: Double($0.last ?? "") ?? 0.0) }
    }
    
    var askMarketOrders: [MarketOrder] {
        asks.map { MarketOrder(price: Double($0.first ?? "") ?? 0.0, quantity: Double($0.last ?? "") ?? 0.0) }
    }
    
    // TODO: - What will be if we are asking about quantity which is bigger than orderbook have - possible for rare symbols
    func getWeightedAveragePrice(for orderSide: OrderSide, amount: Double) -> Double {
        let marketOrders: [MarketOrder] = orderSide == .baseToQuote ? bidMarketOrders : askMarketOrders
        
        var priceQuantityMultiplicationSummary: Double = 0
        var quantitySummary: Double = 0
        var leftoverAmount = amount
        for marketOrder in marketOrders {
            guard leftoverAmount > 0 else { break }
            
            if leftoverAmount > marketOrder.quantity {
                priceQuantityMultiplicationSummary += marketOrder.price * marketOrder.quantity
                quantitySummary += marketOrder.quantity
            } else {
                priceQuantityMultiplicationSummary += marketOrder.price * leftoverAmount
                quantitySummary += leftoverAmount
            }
            leftoverAmount -= marketOrder.quantity
        }
        
        return priceQuantityMultiplicationSummary / quantitySummary
    }
    
}
