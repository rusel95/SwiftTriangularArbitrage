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
    let bids: [[String]]
    let asks: [[String]]
    
    var bidMarketOrders: [MarketOrder] {
        bids.map { MarketOrder(price: Double($0.first ?? "") ?? 0.0, quantity: Double($0.last ?? "") ?? 0.0) }
    }
    
    var askMarketOrders: [MarketOrder] {
        asks.map { MarketOrder(price: Double($0.first ?? "") ?? 0.0, quantity: Double($0.last ?? "") ?? 0.0) }
    }
    
    func getAveragePrice(for orderSide: OrderSide) -> Double {
        let sortetMarketOrders: [MarketOrder]
        switch orderSide {
        case .baseToQuote:
            sortetMarketOrders = bidMarketOrders.sorted(by: { $0.quantity < $1.quantity })
        case .quoteToBase:
            sortetMarketOrders = askMarketOrders.sorted(by: { $0.quantity < $1.quantity })
        case .unknown:
            sortetMarketOrders = []
        }
        
        guard let minimalQuantity = sortetMarketOrders.first?.quantity else { return 0.0 }
        
        var multiplers: Double = 0
        let totalPrice = sortetMarketOrders.reduce(0.0) { partialResult, marketOrder in
            let multipler = marketOrder.quantity / minimalQuantity
            multiplers += multipler
            return partialResult + (multipler * marketOrder.price)
        }
        return totalPrice / multiplers
    }
    
    func getQuantity(for orderSide: OrderSide) -> Double {
        (orderSide == .baseToQuote ? bidMarketOrders : askMarketOrders)
            .reduce(0.0) { partialResult, marketOrder in return partialResult + marketOrder.quantity }
    }
    
}
