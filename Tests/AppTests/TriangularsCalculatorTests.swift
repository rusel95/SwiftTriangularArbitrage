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

    func testExample() throws {
        let symbols = BinanceMock.getMock()!.filter { $0.isSpotTradingAllowed && $0.status == .trading }
        
        let triangulars = TriangularsCalculator.getTriangularsInfo(for: .standart, from: symbols)
        assert(triangulars.count == 266)
    }
    
    func test1Triangular() {
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
    
//    func test2Triangular() {
//        let symbols = [
//            Symbol(symbol: "BTCUSDT", baseAsset: "BTC", quoteAsset: "USDT"),
//            Symbol(symbol: "BTCETH", baseAsset: "BTC", quoteAsset: "ETH"),
//            Symbol(symbol: "ETHUSDT", baseAsset: "ETH", quoteAsset: "USDT"),
//            Symbol(symbol: "LTCUSDT", baseAsset: "LTC", quoteAsset: "USDT"),
//            Symbol(symbol: "BTCLTC", baseAsset: "BTC", quoteAsset: "LTC"),
//        ]
//        let triangulars = TriangularsCalculator.getTriangularsInfo(for: .standart, from: symbols)
//        assert(triangulars.count == 2)
//    }
//
//    func test4Triangular() {
//        let symbols = [
//            Symbol(symbol: "BTCUSDT", baseAsset: "BTC", quoteAsset: "USDT"),
//            Symbol(symbol: "BTCETH", baseAsset: "BTC", quoteAsset: "ETH"),
//            Symbol(symbol: "ETHUSDT", baseAsset: "ETH", quoteAsset: "USDT"),
//            Symbol(symbol: "LTCUSDT", baseAsset: "LTC", quoteAsset: "USDT"),
//            Symbol(symbol: "BTCLTC", baseAsset: "BTC", quoteAsset: "LTC"),
//            Symbol(symbol: "ETHLTC", baseAsset: "ETH", quoteAsset: "LTC"),
//        ]
//        let triangulars = TriangularsCalculator.getTriangularsInfo(for: .standart, from: symbols)
//        assert(triangulars.count == 4)
//    }
//
//    func test5Triangular() {
//        let symbols = [
//            Symbol(symbol: "BTCUSDT", baseAsset: "BTC", quoteAsset: "USDT"),
//            Symbol(symbol: "BTCETH", baseAsset: "BTC", quoteAsset: "ETH"),
//            Symbol(symbol: "ETHUSDT", baseAsset: "ETH", quoteAsset: "USDT"),
//            Symbol(symbol: "LTCUSDT", baseAsset: "LTC", quoteAsset: "USDT"),
//            Symbol(symbol: "BTCLTC", baseAsset: "BTC", quoteAsset: "LTC"),
//            Symbol(symbol: "ETHLTC", baseAsset: "ETH", quoteAsset: "LTC"),
//            Symbol(symbol: "BNBUSDT", baseAsset: "BNB", quoteAsset: "USDT"),
//            Symbol(symbol: "BNBBTC", baseAsset: "BNB", quoteAsset: "BTC"),
//        ]
//        let triangulars = TriangularsCalculator.getTriangularsInfo(for: .standart, from: symbols)
//        assert(triangulars.count == 5)
//    }
//
//    func test7Triangular() {
//        let symbols = [
//            Symbol(symbol: "BTCUSDT", baseAsset: "BTC", quoteAsset: "USDT"),
//            Symbol(symbol: "BTCETH", baseAsset: "BTC", quoteAsset: "ETH"),
//            Symbol(symbol: "ETHUSDT", baseAsset: "ETH", quoteAsset: "USDT"),
//            Symbol(symbol: "LTCUSDT", baseAsset: "LTC", quoteAsset: "USDT"),
//            Symbol(symbol: "BTCLTC", baseAsset: "BTC", quoteAsset: "LTC"),
//            Symbol(symbol: "ETHLTC", baseAsset: "ETH", quoteAsset: "LTC"),
//            Symbol(symbol: "BNBUSDT", baseAsset: "BNB", quoteAsset: "USDT"),
//            Symbol(symbol: "BNBBTC", baseAsset: "BNB", quoteAsset: "BTC"),
//            Symbol(symbol: "BNBETH", baseAsset: "BNB", quoteAsset: "ETH"),
//        ]
//        let triangulars = TriangularsCalculator.getTriangularsInfo(for: .standart, from: symbols)
//        assert(triangulars.count == 7)
//    }
//
    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            do {
                let symbols = BinanceMock.getMock()!.filter { $0.isSpotTradingAllowed && $0.status == .trading }
                
                let triangulars = TriangularsCalculator.getTriangularsInfo(for: .standart, from: symbols)
                assert(triangulars.count == 266)
            } catch {
                print(error.localizedDescription)
            }
        }
    }

}
