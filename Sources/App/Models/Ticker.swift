//
//  Ticker.swift
//  
//
//  Created by Ruslan on 17.11.2022.
//

import Foundation

struct Ticker: Codable {
    let e: String   // Event type
    let E: UInt     // Event time
    let s: String   // Symbol
    let p: String   // Price change
    let P: String   // Price change percent
    let w: String   // Weighted average price
    let x: String   // First trade(F)-1 price (first trade before the 24hr rolling window)
    let c: String   // Last price
    let Q: String   // Last quantity
    let b: String   // Best bid price
    let B: String   // Best bid quantity
    let a: String   // Best ask price
    let A: String   // Best ask quantity
    let o: String   // Open price
    let h: String   // High price
    let l: String   // Low price
    let v: String   // Total traded base asset volume
    let q: String   // Total traded quote asset volume
    let O: UInt     // Statistics open time
    let C: UInt     // Statistics close time
    let F: UInt     // First trade ID
    let L: UInt     // Last trade Id
    let n: UInt     // Total number of trades
    
    var sellPrice: Double? {
        Double(b)
    }
    
    var buyPrice: Double? {
        Double(a)
    }
}

struct BookTicker: Codable {
    
    let symbol: String
    let bidPrice: String
    let bidQty: String
    let askPrice: String
    let askQty: String
    
    var sellPrice: Double? {
        Double(bidPrice)
    }
    
    var buyPrice: Double? {
        Double(askPrice)
    }
    
    init(from ticker: Ticker) {
        self.symbol = ticker.s
        self.bidPrice = ticker.b
        self.bidQty = ticker.B
        self.askPrice = ticker.a
        self.askQty = ticker.A
    }
    
}
