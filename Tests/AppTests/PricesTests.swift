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
        asks: [["5", "1"], ["6", "2"], ["7", "3"], ["8", "4"], ["9", "5"]],
        bids: [["4", "1"], ["3", "2"], ["2", "3"], ["1", "5"]]
    )
    
    func testGetAveragePrice() throws {
        let averageSellPrice = orderbookDepth.getAveragePrice(for: .baseToQuote)
        XCTAssertEqual(averageSellPrice, 1.909, accuracy: 0.0001)
        
        let averageBuyPrice = orderbookDepth.getAveragePrice(for: .quoteToBase)
        XCTAssertEqual(averageBuyPrice, 7.6666, accuracy: 0.0001)
    }
    
    func testGetProbableDepthPrice() throws {
        let probableSellPrice = orderbookDepth.getProbableDepthPrice(for: .baseToQuote, amount: 4)
        XCTAssertEqual(probableSellPrice, 2.6666, accuracy: 0.0001)
        
        let probableBuyPrice = orderbookDepth.getProbableDepthPrice(for: .quoteToBase, amount: 5)
        XCTAssertEqual(probableBuyPrice, 6.3333, accuracy: 0.0001)
    }
    
}
