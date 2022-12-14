//
//  PricesTests.swift
//  
//
//  Created by Ruslan on 14.12.2022.
//

import Foundation

@testable import App
import XCTVapor

final class PricesTests: XCTestCase {
    
    let orderbookDepth = OrderbookDepth(
        lastUpdateId: 1,
        asks: [["5", "1"], ["6", "2"], ["7", "3"]],
        bids: [["4", "1"], ["3", "2"], ["2", "3"]]
    )
    
    func testGetAveragePrice() throws {
        let averageSellPrice = orderbookDepth.getAveragePrice(for: .baseToQuote)
        XCTAssertEqual(averageSellPrice, 2.66666, accuracy: 0.0001)
        
        let averageBuyPrice = orderbookDepth.getAveragePrice(for: .quoteToBase)
        XCTAssertEqual(averageBuyPrice, 6.33333, accuracy: 0.0001)
    }
    
}
