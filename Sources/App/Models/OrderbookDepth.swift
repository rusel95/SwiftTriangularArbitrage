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
    
    func getWeightedAveragePrice(for orderSide: OrderSide, amount: Double) -> Double {
        let sortedMarketOrders: [MarketOrder] = orderSide == .baseToQuote
            ? bidMarketOrders.sorted(by: { $0.price > $1.price })
            : askMarketOrders.sorted(by: { $0.price < $1.price })
        
        var marketOrdersToFullfill: [MarketOrder] = []

        var leftoverAmount = amount
        sortedMarketOrders.forEach { marketOrder in
            if leftoverAmount > 0 {
                if leftoverAmount < marketOrder.quantity {
                    marketOrdersToFullfill.append(MarketOrder(price: marketOrder.price, quantity: leftoverAmount))
                } else {
                    marketOrdersToFullfill.append(marketOrder)
                }
                leftoverAmount -= marketOrder.quantity
            }
        }
        
        let priceQuantityMultiplicationSummary = marketOrdersToFullfill.reduce(0) { partialResult, order in
            partialResult + order.price * order.quantity
        }
        let quantitySummary = marketOrdersToFullfill.reduce(0) { partialResult, order in
            partialResult + order.quantity
        }
        return priceQuantityMultiplicationSummary / quantitySummary
    }
    
    func getQuantity(for orderSide: OrderSide) -> Double {
        (orderSide == .baseToQuote ? bidMarketOrders : askMarketOrders)
            .reduce(0.0) { partialResult, marketOrder in return partialResult + marketOrder.quantity }
    }
    
}
