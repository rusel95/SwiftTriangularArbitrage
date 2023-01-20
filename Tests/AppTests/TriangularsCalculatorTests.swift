//
//  TriangularsCalculatorTests.swift
//  
//
//  Created by Ruslan on 19.01.2023.
//

import XCTest
@testable import App

struct Symbol: TradeableSymbol {
    let symbol: String
    let baseAsset: String
    let quoteAsset: String
}

final class TriangularsCalculatorTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testTriangularCalculator_When3PairsWithSharedAssets_ShouldReturn6() {
        let symbols = [
            Symbol(symbol: "BTCUSDT", baseAsset: "BTC", quoteAsset: "USDT"),
            Symbol(symbol: "ETHBTC", baseAsset: "ETH", quoteAsset: "BTC"),
            Symbol(symbol: "ETHUSDT", baseAsset: "ETH", quoteAsset: "USDT")
        ]
        // 1) sell BTCUSDT -> buy  ETHUSDT -> sell ETHBTC     => more BTC
        // 2) buy  BTCUSDT -> buy  ETHBTC  -> sell ETHUSDT    => more USDT
        // 3) sell ETHBTC  -> sell BTCUSDT -> buy  ETHUSDT    => more ETH
        // 4) buy  ETHBTC  -> sell ETHUSDT -> buy  BTCUSDT    => more BTC
        // 5) sell ETHUSDT -> buy  BTCUSDT -> buy  ETHBTC     => more ETH
        // 6) buy  ETHUSDT -> sell ETHBTC  -> sell BTCUSDT    => more USDT
        let triangulars = TriangularsCalculator.getTriangularsInfo(for: .standart, from: symbols)
        assert(triangulars.count == 6)
    }
    
    func testTriangularCalculator_When5PairsWithSharedAssets_ShouldReturn12() {
        let symbols = [
            Symbol(symbol: "BTCUSDT", baseAsset: "BTC", quoteAsset: "USDT"),
            Symbol(symbol: "ETHBTC", baseAsset: "ETH", quoteAsset: "BTC"),
            Symbol(symbol: "ETHUSDT", baseAsset: "ETH", quoteAsset: "USDT"),
            Symbol(symbol: "LTCUSDT", baseAsset: "LTC", quoteAsset: "USDT"),
            Symbol(symbol: "BTCLTC", baseAsset: "BTC", quoteAsset: "LTC")
        ]
        // 1) sell BTCUSDT -> buy  ETHUSDT -> sell ETHBTC     => more BTC
        // 2) sell BTCUSDT -> buy  LTCUSDT -> buy  BTCLTC     => more BTC
        // 3) buy  BTCUSDT -> buy  ETHBTC  -> sell ETHUSDT    => more USDT
        // 4) buy  BTCUSDT -> sell BTCLTC  -> sell LTCUSDT    => more USDT
        // 5) sell BTCLTC  -> sell LTCUSDT -> buy  BTCUSDT    => more BTC
        // 6) buy  BTCLTC  -> sell BTCUSDT -> buy  LTCUSD     => more LTC
        // 7) sell ETHBTC  -> sell BTCUSDT -> buy  ETHUSDT    => more ETH
        // 8) buy  ETHBTC  -> sell ETHUSDT -> buy  BTCUSDT    => more BTC
        // 9) sell ETHUSDT -> buy  BTCUSDT -> buy  ETHBTC     => more ETH
        // 10)buy  ETHUSDT -> sell ETHBTC  -> sell BTCUSDT    => more USDT
        // 11)sell LTCUSDT -> buy  BTCUSDT -> sell BTCLTC     => more LTC
        // 12)buy  LTCUSDT -> buy  BTCLTC  -> sell BTCUSDT    => more USDT
        let triangulars = TriangularsCalculator.getTriangularsInfo(for: .standart, from: symbols)
        assert(triangulars.count == 12)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            let symbols = BinanceMock.getMock()!
                .filter { $0.status == .trading && $0.isSpotTradingAllowed }
                .filter { $0.baseAsset != "RUB" && $0.quoteAsset != "RUB" }
            
            let triangulars = TriangularsCalculator.getTriangularsInfo(for: .standart, from: symbols)
            assert(triangulars.count == 14148)
        }
    }

}
