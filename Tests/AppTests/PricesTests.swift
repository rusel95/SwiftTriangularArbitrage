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
        bids: [["4", "1"], ["3", "2"], ["2", "3"], ["1", "4"], ["0.5", "5"]]
    )
    
    func testProbableDepthPrice_WhenSellingFour_ReturnThree() throws {
        let probableSellPrice = orderbookDepth.getWeightedAveragePrice(for: .baseToQuote, amount: 4)
        XCTAssertEqual(probableSellPrice, 3)
    }
    
    func testProbableDepthPrice_WhenSellingTen_ReturnTwo() throws {
        let probableSellPrice = orderbookDepth.getWeightedAveragePrice(for: .baseToQuote, amount: 10)
        XCTAssertEqual(probableSellPrice, 2)
    }
    
    func testProbableDepthPrice_WhenSellingAllFifteen_Return1PointFive() throws {
        let probableSellPrice = orderbookDepth.getWeightedAveragePrice(for: .baseToQuote, amount: 15)
        XCTAssertEqual(probableSellPrice, 1.5)
    }
    
    func testProbableDepthPrice_WhenBuyingFive_ReturnSixPointTwo() throws {
        let probableBuyPrice = orderbookDepth.getWeightedAveragePrice(for: .quoteToBase, amount: 5)
        XCTAssertEqual(probableBuyPrice, 6.2)
    }
    
    func testProbableDepthPrice_WhenBuyingTen_ReturnSeven() throws {
        let probableBuyPrice = orderbookDepth.getWeightedAveragePrice(for: .quoteToBase, amount: 10)
        XCTAssertEqual(probableBuyPrice, 7)
    }
    
    func testProbableDepthPrice_WhenBuyingAllFifteenOrderbook_ReturnSevenPeriodSix() throws {
        let probableBuyPrice = orderbookDepth.getWeightedAveragePrice(for: .quoteToBase, amount: 15)
        XCTAssertEqual(probableBuyPrice, 7.666, accuracy: 0.001)
    }
    
}
