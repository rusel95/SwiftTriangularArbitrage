//
//  DepthCheckService.swift
//  
//
//  Created by Ruslan on 16.01.2023.
//

import Foundation

import Vapor

final class DepthCheckService {
    
    private let allowedAssetsToTrade: Set<String> = Set(arrayLiteral: "BUSD", "USDT", "USDC", "TUSD", "BTC", "ETH", "BNB", "UAH")
    
    private var bookTickersDict: [String: BookTicker] = [:]
    
    private var minimumQuantityMultipler: Double = {
#if DEBUG
        return 1.5
#else
        return 3
#endif
    }()
    
    private let emailService: EmailService
    private let app: Application
    private let maximalDifferencePercent = 0.2
    
    private let minimumQuantityStableEquivalent: Double
    
    init(app: Application) {
        self.app = app
        self.emailService = EmailService(app: app)

        minimumQuantityStableEquivalent = 10.0 * minimumQuantityMultipler
        
        do {
            let jsonData = try Data(contentsOf: Constants.Binance.tradeableDictURL)
            let tradeableSymbolsDict = try JSONDecoder().decode([String: BinanceAPIService.Symbol].self, from: jsonData)
            let _ = app.caches.memory.set(Constants.Binance.tradeableSymbolsDictKey, to: tradeableSymbolsDict)
        } catch {
            print(error.localizedDescription)
        }
    }
    
    // MARK: - Depth Check
    
    func handle(
        stockExchange: StockExchange,
        opportunity: TriangularOpportunity,
        bookTickersDict: [String: BookTicker],
        for userInfo: UserInfo
    ) async throws -> TriangularOpportunity {
        opportunity.autotradeCicle = .depthCheck
        
        guard let lastSurfaceResult = opportunity.surfaceResults.last else {
            opportunity.autotradeCicle = .forbidden
            opportunity.autotradeLog.append("no last result..")
            return opportunity
        }
        
        self.bookTickersDict = bookTickersDict
        
        do {
            let depth: TriangularOpportunityDepth
            switch stockExchange {
            case .binance:
                depth = try await getBinanceDepth(for: lastSurfaceResult, limit: 6)
            case .bybit:
                opportunity.autotradeCicle = .forbidden
                return opportunity
            case .huobi:
                depth = try await getHuobiDepth(for: lastSurfaceResult)
            case .exmo:
                opportunity.autotradeCicle = .forbidden
                return opportunity
            case .kucoin:
                depth = try await getKucoinDepth(for: lastSurfaceResult)
            case .kraken:
                depth = try await getKrakenDepth(for: lastSurfaceResult)
            case .whitebit:
                opportunity.autotradeCicle = .forbidden
                return opportunity
            case .gateio:
                depth = try await getGateIODepth(for: lastSurfaceResult)
            }
            
            let trade1ApproximateOrderbookQuantity = try getApproximateMinimalAssetPortionToReceive(contract: lastSurfaceResult.contract1, asset: lastSurfaceResult.swap0)
            let trade1AveragePrice = depth.pairADepth.getProbableDepthPrice(
                for: lastSurfaceResult.directionTrade1,
                amount: trade1ApproximateOrderbookQuantity * 4 // to be sure our amount exist
            )
            let trade1PriceDifferencePercent = (trade1AveragePrice - lastSurfaceResult.pairAExpectedPrice) / lastSurfaceResult.pairAExpectedPrice * 100.0
            
            guard (lastSurfaceResult.directionTrade1 == .baseToQuote && trade1PriceDifferencePercent >= -maximalDifferencePercent) ||
                    (lastSurfaceResult.directionTrade1 == .quoteToBase && trade1PriceDifferencePercent <= maximalDifferencePercent)
            else {
                opportunity.autotradeLog.append("\nTrade 1 price: \(trade1AveragePrice.string()) (\(trade1PriceDifferencePercent.string(maxFractionDigits: 2))% diff)")
                opportunity.autotradeCicle = .pending
                return opportunity
            }
            
            let trade2ApproximateOrderbookQuantity = try getApproximateMinimalAssetPortionToReceive(contract: lastSurfaceResult.contract2, asset: lastSurfaceResult.swap1)
            let trade2AveragePrice = depth.pairBDepth.getProbableDepthPrice(
                for: lastSurfaceResult.directionTrade2,
                amount: trade2ApproximateOrderbookQuantity * 5 // Extra
            )
            let trade2PriceDifferencePercent = (trade2AveragePrice - lastSurfaceResult.pairBExpectedPrice) / lastSurfaceResult.pairBExpectedPrice * 100.0
            guard (lastSurfaceResult.directionTrade2 == .baseToQuote && trade2PriceDifferencePercent >= -maximalDifferencePercent) ||
                    (lastSurfaceResult.directionTrade2 == .quoteToBase && trade2PriceDifferencePercent <= maximalDifferencePercent)
            else {
                opportunity.autotradeLog.append("\nTrade 2 price: \(trade2AveragePrice.string(maxFractionDigits: 5)) (\(trade2PriceDifferencePercent.string(maxFractionDigits: 2))% diff)")
                opportunity.autotradeCicle = .pending
                return opportunity
            }
            
            let trade3ApproximateOrderbookQuantity = try getApproximateMinimalAssetPortionToReceive(contract: lastSurfaceResult.contract3, asset: lastSurfaceResult.swap2)
            let trade3AveragePrice = depth.pairCDepth.getProbableDepthPrice(
                for: lastSurfaceResult.directionTrade3,
                amount: trade3ApproximateOrderbookQuantity * 6
            )
            let trade3PriceDifferencePercent = (trade3AveragePrice - lastSurfaceResult.pairCExpectedPrice) / lastSurfaceResult.pairCExpectedPrice * 100.0
            guard (lastSurfaceResult.directionTrade3 == .baseToQuote && trade3PriceDifferencePercent >= -maximalDifferencePercent) ||
                    (lastSurfaceResult.directionTrade3 == .quoteToBase && trade3PriceDifferencePercent <= maximalDifferencePercent)
            else {
                opportunity.autotradeLog.append("\nTrade 3 price: \(trade3AveragePrice.string()) (\(trade3PriceDifferencePercent.string(maxFractionDigits: 2))% diff)")
                opportunity.autotradeCicle = .pending
                return opportunity
            }
            
            opportunity.autotradeCicle = .readyToTrade
            return opportunity
        } catch {
            opportunity.autotradeLog.append(error.localizedDescription)
            emailService.sendEmail(subject: "[\(stockExchange)] [depth] \(error.localizedDescription)",
                                   text: opportunity.description)
            return opportunity
        }
    }
    
}

// MARK: - Depth

private extension DepthCheckService {
    
    func getBinanceDepth(for surfaceResult: SurfaceResult, limit: UInt) async throws -> TriangularOpportunityDepth {
        async let pairADepthData = BinanceAPIService.shared.getOrderbookDepth(symbol: surfaceResult.contract1, limit: limit)
        async let pairBDepthData = BinanceAPIService.shared.getOrderbookDepth(symbol: surfaceResult.contract2, limit: limit)
        async let pairCDepthData = BinanceAPIService.shared.getOrderbookDepth(symbol: surfaceResult.contract3, limit: limit)
        
        let (pairADepth, pairBDepth, pairCDepth) = try await (pairADepthData, pairBDepthData, pairCDepthData)
        return TriangularOpportunityDepth(pairADepth: pairADepth,
                                          pairBDepth: pairBDepth,
                                          pairCDepth: pairCDepth)
    }
    
    
    func getKucoinDepth(for surfaceResult: SurfaceResult) async throws -> TriangularOpportunityDepth {
        async let pairADepthData = KuCoinAPIService.shared.getOrderbookDepth(symbol: surfaceResult.contract1)
        async let pairBDepthData = KuCoinAPIService.shared.getOrderbookDepth(symbol: surfaceResult.contract2)
        async let pairCDepthData = KuCoinAPIService.shared.getOrderbookDepth(symbol: surfaceResult.contract3)
        
        let (pairADepth, pairBDepth, pairCDepth) = try await (pairADepthData, pairBDepthData, pairCDepthData)
        return TriangularOpportunityDepth(pairADepth: pairADepth,
                                          pairBDepth: pairBDepth,
                                          pairCDepth: pairCDepth)
    }
    
    func getKrakenDepth(for surfaceResult: SurfaceResult) async throws -> TriangularOpportunityDepth {
        async let pairADepthData = KrakenAPIService.shared.getOrderbookDepth(symbol: surfaceResult.contract1, count: 10)
        async let pairBDepthData = KrakenAPIService.shared.getOrderbookDepth(symbol: surfaceResult.contract2, count: 10)
        async let pairCDepthData = KrakenAPIService.shared.getOrderbookDepth(symbol: surfaceResult.contract3, count: 10)
        
        let (pairADepth, pairBDepth, pairCDepth) = try await (pairADepthData, pairBDepthData, pairCDepthData)
        return TriangularOpportunityDepth(pairADepth: pairADepth,
                                          pairBDepth: pairBDepth,
                                          pairCDepth: pairCDepth)
    }
    
    func getHuobiDepth(for surfaceResult: SurfaceResult) async throws -> TriangularOpportunityDepth {
        async let pairADepthData = HuobiAPIService.shared.getOrderbookDepth(symbol: surfaceResult.contract1)
        async let pairBDepthData = HuobiAPIService.shared.getOrderbookDepth(symbol: surfaceResult.contract2)
        async let pairCDepthData = HuobiAPIService.shared.getOrderbookDepth(symbol: surfaceResult.contract3)
        
        let (pairADepth, pairBDepth, pairCDepth) = try await (pairADepthData, pairBDepthData, pairCDepthData)
        return TriangularOpportunityDepth(pairADepth: pairADepth, pairBDepth: pairBDepth, pairCDepth: pairCDepth)
    }
    
    func getGateIODepth(for surfaceResult: SurfaceResult) async throws -> TriangularOpportunityDepth {
        async let pairADepthData = GateIOAPIService.shared.getOrderbookDepth(symbol: surfaceResult.contract1, limit: 10)
        async let pairBDepthData = GateIOAPIService.shared.getOrderbookDepth(symbol: surfaceResult.contract2, limit: 10)
        async let pairCDepthData = GateIOAPIService.shared.getOrderbookDepth(symbol: surfaceResult.contract3, limit: 10)
        
        let (pairADepth, pairBDepth, pairCDepth) = try await (pairADepthData, pairBDepthData, pairCDepthData)
        return TriangularOpportunityDepth(pairADepth: pairADepth, pairBDepth: pairBDepth, pairCDepth: pairCDepth)
    }
    
}

// MARK: - Helpers

private extension DepthCheckService {
    
    func getApproximateMinimalAssetPortionToReceive(contract: String, asset: String) throws -> Double {
        let baseAsset = contract.starts(with: asset) ? asset : contract.replace(asset, "")
        return try getApproximateMinimalPortion(for: baseAsset)
    }
    
    func getComparableDescription(
        for response: BinanceAPIService.NewOrderResponse,
        expectedExecutionPrice: Double
    ) -> String {
        let averageExecutedPrice = response.averageExecutedPrice
        let differencePercent = (averageExecutedPrice - expectedExecutionPrice) / expectedExecutionPrice * 100.0
        var text =
        """
        \(response.symbol) \(averageExecutedPrice.string(maxFractionDigits: 8))(\(differencePercent.string(maxFractionDigits: 4))% diff) \(response.side)
        origQty: \((Double(response.origQty) ?? 0.0).string(maxFractionDigits: 8)), executeQty: \((Double(response.executedQty) ?? 0.0).string(maxFractionDigits: 8)), cummulativeQuoteQty: \((Double(response.cummulativeQuoteQty) ?? 0.0).string(maxFractionDigits: 8))
        fills:
        """
        response.fills.forEach { text.append(" (\($0.description))\n") }
        return text
    }
    
    func getApproximateMinimalPortion(for asset: String) throws -> Double {
        let approximateStableEquivalent = try getApproximateStableEquivalent(asset: asset, assetQuantity: 1)
        return minimumQuantityStableEquivalent / approximateStableEquivalent
    }
    
    func getApproximateStableEquivalent(asset: String, assetQuantity: Double) throws -> Double {
        guard Constants.stablesSet.contains(asset) == false else { return assetQuantity }

        if let assetToStableSymbol = bookTickersDict["\(asset)USDT"]
            ?? bookTickersDict["\(asset)-USDT"]
            ?? bookTickersDict["\(asset)"]
            ?? bookTickersDict["\(asset)usdc"],
           let assetToStableApproximatePrice = assetToStableSymbol.sellPrice {
            return assetQuantity * assetToStableApproximatePrice
        } else if let stableToAssetSymbol = bookTickersDict["USDT\(asset)"]
                    ?? bookTickersDict["USDT-\(asset)"]
                    ?? bookTickersDict["usdc\(asset)"],
                  let stableToAssetApproximatePrice = stableToAssetSymbol.buyPrice {
            return assetQuantity / stableToAssetApproximatePrice
        } else {
            throw CommonError.noMinimalPortion(description: "\nNo Approximate Minimal Portion for asset \(asset)")
        }
    }
    
}
