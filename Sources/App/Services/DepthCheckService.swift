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
        opportunity: TriangularOpportunity,
        bookTickersDict: [String: BookTicker],
        for userInfo: UserInfo
    ) async throws -> TriangularOpportunity {
        self.bookTickersDict = bookTickersDict
        
        opportunity.autotradeCicle = .depthCheck
        // NOTE: - remove handling only first - handle all of opportunities
        guard allowedAssetsToTrade.contains(opportunity.firstSurfaceResult.swap0) else {
            opportunity.autotradeCicle = .forbidden
            opportunity.autotradeLog.append("\nNot tradeable opportunity\n")
            return opportunity
        }
        
        guard let lastSurfaceResult = opportunity.surfaceResults.last else {
            opportunity.autotradeCicle = .forbidden
            opportunity.autotradeLog.append("no last result..")
            return opportunity
        }
        
        do {
            let depth = try await getDepth(for: lastSurfaceResult, limit: 6)
            
            let trade1ApproximateOrderbookQuantity = try getApproximateMinimalAssetPortionToReceive(contract: lastSurfaceResult.contract1, asset: lastSurfaceResult.swap0)
            let trade1AveragePrice = depth.pairADepth.getProbableDepthPrice(
                for: lastSurfaceResult.directionTrade1,
                amount: trade1ApproximateOrderbookQuantity * 4 // to be sure our amount exist
            )
            let trade1PriceDifferencePercent = (trade1AveragePrice - lastSurfaceResult.pairAExpectedPrice) / lastSurfaceResult.pairAExpectedPrice * 100.0
            
            guard (lastSurfaceResult.directionTrade1 == .baseToQuote && trade1PriceDifferencePercent >= -maximalDifferencePercent) ||
                    (lastSurfaceResult.directionTrade1 == .quoteToBase && trade1PriceDifferencePercent <= maximalDifferencePercent)
            else {
                opportunity.autotradeLog.append("\nTrade 1 price: \(trade1AveragePrice.string()) (\(trade1PriceDifferencePercent.string(maxFractionDigits: 2))% diff)\n")
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
                opportunity.autotradeLog.append("\nTrade 2 price: \(trade2AveragePrice.string(maxFractionDigits: 5)) (\(trade2PriceDifferencePercent.string(maxFractionDigits: 2))% diff)\n")
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
                opportunity.autotradeLog.append("\nTrade 3 price: \(trade3AveragePrice.string()) (\(trade3PriceDifferencePercent.string(maxFractionDigits: 2))% diff)\n")
                opportunity.autotradeCicle = .pending
                return opportunity
            }
            
            opportunity.autotradeCicle = .readyToTrade
            return opportunity
        } catch {
            opportunity.autotradeLog.append(error.localizedDescription)
            emailService.sendEmail(subject: "unexpected error: \(error.localizedDescription)",
                                   text: opportunity.description)
            return opportunity
        }
    }
    
}

// MARK: - Helpers

private extension DepthCheckService {
    
    func getDepth(for surfaceResult: SurfaceResult, limit: UInt) async throws -> TriangularOpportunityDepth {
        async let pairADepthData = BinanceAPIService.shared.getOrderbookDepth(symbol: surfaceResult.contract1, limit: limit)
        async let pairBDepthData = BinanceAPIService.shared.getOrderbookDepth(symbol: surfaceResult.contract2, limit: limit)
        async let pairCDepthData = BinanceAPIService.shared.getOrderbookDepth(symbol: surfaceResult.contract3, limit: limit)
        
        let (pairADepth, pairBDepth, pairCDepth) = try await (pairADepthData, pairBDepthData, pairCDepthData)
        return TriangularOpportunityDepth(pairADepth: pairADepth, pairBDepth: pairBDepth, pairCDepth: pairCDepth)
    }
    
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

        if let assetToStableSymbol = bookTickersDict["\(asset)USDT"], let assetToStableApproximatePrice = assetToStableSymbol.sellPrice {
            return assetQuantity * assetToStableApproximatePrice
        } else if let stableToAssetSymbol = bookTickersDict["USDT\(asset)"], let stableToAssetApproximatePrice = stableToAssetSymbol.buyPrice {
            return assetQuantity / stableToAssetApproximatePrice
        } else {
            throw TradingError.noMinimalPortion(description: "\nNo Approximate Minimal Portion for asset \(asset)")
        }
    }
    
}
