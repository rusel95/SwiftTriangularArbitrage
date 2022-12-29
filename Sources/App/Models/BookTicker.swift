//
//  BookTicker.swift
//  
//
//  Created by Ruslan on 17.11.2022.
//

import Foundation

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
    
}
