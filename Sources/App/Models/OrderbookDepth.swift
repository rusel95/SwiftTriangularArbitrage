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
    
    func getAveragePrice(for orderSide: OrderSide) -> Double {
        let sortedMarketOrders: [MarketOrder] = orderSide == .baseToQuote
            ? bidMarketOrders.sorted(by: { $0.quantity < $1.quantity })
            : askMarketOrders.sorted(by: { $0.quantity < $1.quantity })
        
        guard let minimalQuantity = sortedMarketOrders.first?.quantity else { return 0.0 }
        
        var multiplers: Double = 0
        let totalPrice = sortedMarketOrders.reduce(0.0) { partialResult, marketOrder in
            let multipler = marketOrder.quantity / minimalQuantity
            multiplers += multipler
            return partialResult + (multipler * marketOrder.price)
        }
        return totalPrice / multiplers
    }
    
    // Returns probable price for specific amount of coin
    func getProbableDepthPrice(for orderSide: OrderSide, amount: Double) -> Double {
        let sortedMarketOrders: [MarketOrder] = orderSide == .baseToQuote
            ? bidMarketOrders.sorted(by: { $0.price > $1.price })
            : askMarketOrders.sorted(by: { $0.price < $1.price })
        
        var marketOrdersToFullfill: [MarketOrder] = []
        
        var leftoverAmount = amount
        sortedMarketOrders.forEach { marketOrder in
            if leftoverAmount > 0 {
                leftoverAmount -= marketOrder.quantity
                marketOrdersToFullfill.append(marketOrder)
            }
        }
        return 0
    }
    
    func getQuantity(for orderSide: OrderSide) -> Double {
        (orderSide == .baseToQuote ? bidMarketOrders : askMarketOrders)
            .reduce(0.0) { partialResult, marketOrder in return partialResult + marketOrder.quantity }
    }
    
}
