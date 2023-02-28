//
//  AutoTradingService.swift
//  
//
//  Created by Ruslan on 12.10.2022.
//

import CoreFoundation
import Vapor

final class AutoTradingService {
    
    struct TradeResult {
        let opportunity: TriangularOpportunity
        let usedCapital: Double
        let resultingCapital: Double
        let commission: Double
    }
    
    private var bookTickersDict: [String: BookTicker] = [:]
    
    private var minimumQuantityMultipler: Double = {
#if DEBUG
        return 2
#else
        return 3
#endif
    }()
    
    private let minimumQuantityStableEquivalent: Double
    private let maximalDifferencePercent = 0.2
    
    private let emailService: EmailService
    private let app: Application
    
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
    
    func parralelTrade(opportunity: TriangularOpportunity, bookTickersDict: [String: BookTicker]) async throws -> TriangularOpportunity {
        guard Constants.tradeableAssets.contains(opportunity.firstSurfaceResult.swap0) else {
            opportunity.autotradeCicle = .forbidden
            opportunity.autotradeLog.append("\nNot tradeable opportunity\n")
            return opportunity
        }
        
        self.bookTickersDict = bookTickersDict
        
        do {
            opportunity.autotradeCicle = .trading
            
            let trade1Quantity = try await getMimimumTradeQuantityFor(
                contract: opportunity.firstSurfaceResult.contract1,
                directionTrade: opportunity.firstSurfaceResult.directionTrade1,
                asset: opportunity.firstSurfaceResult.swap0
            )
            let trade2Quantity = try await getMimimumTradeQuantityFor(
                contract: opportunity.firstSurfaceResult.contract2,
                directionTrade: opportunity.firstSurfaceResult.directionTrade2,
                asset: opportunity.firstSurfaceResult.swap1
            )
            let trade3Quantity = try await getMimimumTradeQuantityFor(
                contract: opportunity.firstSurfaceResult.contract3,
                directionTrade: opportunity.firstSurfaceResult.directionTrade3,
                asset: opportunity.firstSurfaceResult.swap2
            )
            async let firstTradeResult = try handleFirstTrade(
                for: opportunity,
                preferableQuontity: trade1Quantity
            )
            
            async let secondTradeResult = try handleSecondTrade(
                for: opportunity,
                preferableQuantity: trade2Quantity
            )
            async let thirdTradeResult = try handleThirdTrade(
                for: opportunity,
                preferableQuantity: trade3Quantity
            )
            
            let tradeResponses: [TradeResult] = try await [firstTradeResult, secondTradeResult, thirdTradeResult]
            
            opportunity.autotradeCicle = .completed
            
            let totalComissionStableEquivalent = tradeResponses[0].commission + tradeResponses[1].commission + tradeResponses[2].commission
            if totalComissionStableEquivalent > 0 {
                opportunity.autotradeLog.append("\n\nTotal comission: ≈ \(totalComissionStableEquivalent.string(maxFractionDigits: 4)) USDT")
            }
         
            let usedSwap0AssetCapitalStableEquivalent = try getApproximateStableEquivalent(
                asset: opportunity.firstSurfaceResult.swap0,
                assetQuantity: tradeResponses[0].usedCapital
            )
            let resultingSwap0AssetStableEquivalent = try getApproximateStableEquivalent(
                asset: opportunity.firstSurfaceResult.swap0,
                assetQuantity: tradeResponses[2].resultingCapital
            )
            
            let usedSwap1AssetCapitalStableEquivalent = try getApproximateStableEquivalent(
                asset: opportunity.firstSurfaceResult.swap1,
                assetQuantity: tradeResponses[1].usedCapital
            )
            let resultingSwap1AssetCapitalStableEquivalent = try getApproximateStableEquivalent(asset: opportunity.firstSurfaceResult.swap1, assetQuantity: tradeResponses[0].resultingCapital)
            
            let usedSwap2AssetCapitalStableEquivalent = try getApproximateStableEquivalent(asset: opportunity.firstSurfaceResult.swap2, assetQuantity: tradeResponses[2].usedCapital)
            let resultingSwap2AssetCapitalStableEquivalent = try getApproximateStableEquivalent(asset: opportunity.firstSurfaceResult.swap2, assetQuantity: tradeResponses[1].resultingCapital)
            
            let allUsedAssetsStableEquivalent = usedSwap0AssetCapitalStableEquivalent + usedSwap1AssetCapitalStableEquivalent + usedSwap2AssetCapitalStableEquivalent
            let allResultingAssetsStableEquivalent = resultingSwap0AssetStableEquivalent + resultingSwap1AssetCapitalStableEquivalent + resultingSwap2AssetCapitalStableEquivalent
            
            opportunity.autotradeLog.append("\nUsed Capital: \(allUsedAssetsStableEquivalent) | Resulting Capital: \(allResultingAssetsStableEquivalent)")
            
            let profit: Double = allResultingAssetsStableEquivalent - allUsedAssetsStableEquivalent - totalComissionStableEquivalent
            let actualProfitString = "\nActual Profit: ≈ \(profit.string(maxFractionDigits: 4)) USDT"
            
            opportunity.autotradeLog.append(actualProfitString)
            opportunity.autotradeLog.append(" | \((profit / allUsedAssetsStableEquivalent * 100.0).string(maxFractionDigits: 4))%")
            
            emailService.sendEmail(subject: actualProfitString, text: opportunity.tradingDescription)
            return opportunity
        } catch CommonError.noMinimalPortion(let description) {
            opportunity.autotradeCicle = .forbidden
            opportunity.autotradeLog.append(description)
            emailService.sendEmail(subject: description, text: opportunity.description)
            return opportunity
        } catch CommonError.customError(let description) {
            opportunity.autotradeCicle = .forbidden
            opportunity.autotradeLog.append(description)
            emailService.sendEmail(subject: description, text: opportunity.description)
            return opportunity
        } catch BinanceError.unexpected(let description) {
            opportunity.autotradeCicle = .forbidden
            opportunity.autotradeLog.append(description)
            emailService.sendEmail(subject: "binance error: \(description)", text: opportunity.description)
            return opportunity
        } catch {
            opportunity.autotradeCicle = .pending
            opportunity.autotradeLog.append(error.localizedDescription)
            emailService.sendEmail(subject: "unexpected error: \(error.localizedDescription)",
                                   text: opportunity.description)
            return opportunity
        }
    }

    // MARK: - First Trade
    
    private func handleFirstTrade(
        for opportunity: TriangularOpportunity,
        preferableQuontity: Double
    ) async throws -> TradeResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let firstOrderResponse = try await BinanceAPIService.shared.newOrder(
            symbol: opportunity.firstSurfaceResult.contract1,
            side: opportunity.firstSurfaceResult.directionTrade1,
            type: .market,
            quantity: preferableQuontity,
            quoteOrderQty: preferableQuontity,
            newOrderRespType: .full
        )
        
        let description = self.getComparableDescription(for: firstOrderResponse, expectedExecutionPrice: opportunity.firstSurfaceResult.pairAExpectedPrice)
        opportunity.autotradeLog.append("\nStep 1: \(description)")
        
        let commissionStableEquivalent: Double = try getCommissionStableEquivalent(for: firstOrderResponse.fills)
        if commissionStableEquivalent > 0 {
            opportunity.autotradeLog.append("\nCommission: ≈\(commissionStableEquivalent.string(maxFractionDigits: 4))")
        }
        
        let duration = String(format: "%.4f", CFAbsoluteTimeGetCurrent() - startTime)
        opportunity.autotradeLog.append("First trade time: \(duration)s")
        
        let usedAssetQuantity: Double
        let resultingCapital: Double
        switch opportunity.firstSurfaceResult.directionTrade1 {
        case .quoteToBase:
            usedAssetQuantity = Double(firstOrderResponse.cummulativeQuoteQty) ?? 0.0
            resultingCapital = Double(firstOrderResponse.executedQty) ?? 0.0
        case .baseToQuote:
            usedAssetQuantity = Double(firstOrderResponse.executedQty) ?? 0.0
            resultingCapital = Double(firstOrderResponse.cummulativeQuoteQty) ?? 0.0
        case .unknown:
            usedAssetQuantity = 0
            resultingCapital = 0
        }
        
        return TradeResult(
            opportunity: opportunity,
            usedCapital: usedAssetQuantity,
            resultingCapital: resultingCapital,
            commission: commissionStableEquivalent
        )
    }
    // MARK: - Second Trade
    
    private func handleSecondTrade(
        for opportunity: TriangularOpportunity,
        preferableQuantity: Double
    ) async throws -> TradeResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        opportunity.autotradeLog.append("\nQuantity to execute on second trade: \(preferableQuantity) \(opportunity.firstSurfaceResult.swap1)")
        let secondOrderResponse = try await BinanceAPIService.shared.newOrder(
            symbol: opportunity.firstSurfaceResult.contract2,
            side: opportunity.firstSurfaceResult.directionTrade2,
            type: .market,
            quantity: preferableQuantity,
            quoteOrderQty: preferableQuantity,
            newOrderRespType: .full
        )
        let description = getComparableDescription(for: secondOrderResponse, expectedExecutionPrice: opportunity.firstSurfaceResult.pairBExpectedPrice)
        opportunity.autotradeLog.append("\n\nStep 2: \(description)")
        
        let secondOrderComission: Double = try getCommissionStableEquivalent(for: secondOrderResponse.fills)
        if secondOrderComission > 0 {
            opportunity.autotradeLog.append("\nCommission: ≈ \(secondOrderComission.string(maxFractionDigits: 4)) USDT")
        }
        
        let usedAssetQuantity: Double
        let resultingCapital: Double
        switch opportunity.firstSurfaceResult.directionTrade2 {
        case .quoteToBase:
            usedAssetQuantity = Double(secondOrderResponse.cummulativeQuoteQty) ?? 0.0
            resultingCapital = Double(secondOrderResponse.executedQty) ?? 0.0
        case .baseToQuote:
            usedAssetQuantity = Double(secondOrderResponse.executedQty) ?? 0.0
            resultingCapital = Double(secondOrderResponse.cummulativeQuoteQty) ?? 0.0
        case .unknown:
            usedAssetQuantity = 0
            resultingCapital = 0
        }
        
        let duration = String(format: "%.4f", CFAbsoluteTimeGetCurrent() - startTime)
        opportunity.autotradeLog.append("\nSecond trade time: \(duration)s")
        
        return TradeResult(
            opportunity: opportunity,
            usedCapital: usedAssetQuantity,
            resultingCapital: resultingCapital,
            commission: secondOrderComission
        )
    }
    
    // MARK: - Third Trade
    
    private func handleThirdTrade(for opportunity: TriangularOpportunity, preferableQuantity: Double) async throws -> TradeResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        opportunity.autotradeLog.append("\nQuantity to execute on third trade: \(preferableQuantity) \(opportunity.firstSurfaceResult.swap2)")
        let thirdOrderResponse = try await BinanceAPIService.shared.newOrder(
            symbol: opportunity.firstSurfaceResult.contract3,
            side: opportunity.firstSurfaceResult.directionTrade3,
            type: .market,
            quantity: preferableQuantity,
            quoteOrderQty: preferableQuantity,
            newOrderRespType: .full
        )
        
        let description = self.getComparableDescription(for: thirdOrderResponse, expectedExecutionPrice: opportunity.firstSurfaceResult.pairCExpectedPrice)
       
        opportunity.autotradeLog.append("\n\nStep 3: \(description)")
        
        let thirdOrderComission: Double = try getCommissionStableEquivalent(for: thirdOrderResponse.fills)
        if thirdOrderComission > 0 {
            opportunity.autotradeLog.append("\nCommission: \(thirdOrderComission.string(maxFractionDigits: 4)) USDT")
        }
        
        let usedAssetQuantity: Double
        let actualResultingAmount: Double
        switch opportunity.firstSurfaceResult.directionTrade3 {
        case .quoteToBase:
            usedAssetQuantity = Double(thirdOrderResponse.cummulativeQuoteQty) ?? 0.0
            actualResultingAmount = Double(thirdOrderResponse.executedQty) ?? 0.0
        case .baseToQuote:
            usedAssetQuantity = Double(thirdOrderResponse.executedQty) ?? 0.0
            actualResultingAmount = Double(thirdOrderResponse.cummulativeQuoteQty) ?? 0.0
        case .unknown:
            usedAssetQuantity = 0
            actualResultingAmount = 0
        }
        
        let duration = String(format: "%.4f", CFAbsoluteTimeGetCurrent() - startTime)
        opportunity.autotradeLog.append("\nThird trade time: \(duration)s")
        
        return TradeResult(
            opportunity: opportunity,
            usedCapital: usedAssetQuantity,
            resultingCapital: actualResultingAmount,
            commission: thirdOrderComission
        )
    }
    
}

// MARK: - Helpers

private extension AutoTradingService {
    
    func getMimimumTradeQuantityFor(contract: String, directionTrade: OrderSide, asset: String) async throws -> Double {
        guard let tradeableSymbolsDict = try await app.caches.memory.get(
            Constants.Binance.tradeableSymbolsDictKey,
            as: [String: BinanceAPIService.Symbol].self
        ),
            let firstSymbolDetails = tradeableSymbolsDict[contract] else {
            throw CommonError.customError(description: "\nError: No contract1 at tradeable symbols")
        }
        
        guard let firstOrderMinNotionalString = firstSymbolDetails.filters.first(where: { $0.filterType == .minNotional })?.minNotional,
              let firstOrderMinNotional = Double(firstOrderMinNotionalString)
        else {
            throw CommonError.customError(description: "\nError: No min notional")
        }
        
        guard let approximateTickerPrice = bookTickersDict[contract]?.buyPrice else {
            throw CommonError.customError(description: "No approximate ticker price")
        }
        
        let preferableQuantity: Double
        switch directionTrade {
        case .baseToQuote:
            let minNotionalEquivalentQuantity = firstOrderMinNotional * minimumQuantityMultipler / approximateTickerPrice
            let minStableEquivalentQuantity = try getApproximateMinimalPortion(for: asset)
            preferableQuantity = max(minNotionalEquivalentQuantity, minStableEquivalentQuantity)
        case .quoteToBase:
            let minNotionalEquivalentQuantity = firstOrderMinNotional * minimumQuantityMultipler
            let minStableEquivalentQuantity = try getApproximateMinimalPortion(for: asset)
            preferableQuantity = max(minNotionalEquivalentQuantity, minStableEquivalentQuantity)
        case .unknown:
            throw CommonError.customError(description: "Unknown side")
        }
        
        guard let lotSizeMinQtyString = firstSymbolDetails.filters.first(where: { $0.filterType == .lotSize })?.minQty,
              let lotSizeMinQty = Double(lotSizeMinQtyString) else {
            throw CommonError.customError(description: "No Lot_Size for \(contract)")
        }
        
        let leftoversAfterRounding = preferableQuantity.truncatingRemainder(dividingBy: lotSizeMinQty)
        let quantityToExequte = (preferableQuantity - leftoversAfterRounding).roundToDecimal(8)
        
        guard quantityToExequte > 0 else {
            throw CommonError.customError(description: "Quantity to Qxecute is 0 - have to have bigger amount")
        }
        
        return quantityToExequte
    }
    
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
    
    func getApproximateStableEquivalentDescription(asset: String, quantity: Double) throws -> String {
        let approximateStableEquivalent = try getApproximateStableEquivalent(asset: asset, assetQuantity: quantity)
        return " ≈ \(approximateStableEquivalent.string(maxFractionDigits: 4)) USDT"
    }
    
    
    func getCommissionStableEquivalent(for fills: [BinanceAPIService.Fill]) throws -> Double {
        try fills.map { fill in
            if let commission = Double(fill.commission) {
                let approximateStableEquivalent = try getApproximateStableEquivalent(asset: fill.commissionAsset, assetQuantity: commission)
                return approximateStableEquivalent
            } else {
                return 0
            }
        }.reduce(0, { x, y in x + y })
    }
    
    func getApproximateStableEquivalent(asset: String, assetQuantity: Double) throws -> Double {
        guard Constants.stablesSet.contains(asset) == false else { return assetQuantity }
        
        if let assetToStableSymbol = bookTickersDict["\(asset)USDT"], let assetToStableApproximatePrice = assetToStableSymbol.sellPrice {
            return assetQuantity * assetToStableApproximatePrice
        } else if let stableToAssetSymbol = bookTickersDict["USDT\(asset)"], let stableToAssetApproximatePrice = stableToAssetSymbol.buyPrice {
            return assetQuantity / stableToAssetApproximatePrice
        } else {
            throw CommonError.noMinimalPortion(description: "\nNo Approximate Minimal Portion for asset \(asset)")
        }
    }
    
}
