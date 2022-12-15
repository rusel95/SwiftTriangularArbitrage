//
//  AutoTradingService.swift
//  
//
//  Created by Ruslan on 12.10.2022.
//

import Jobs
import CoreFoundation

final class AutoTradingService {
    
    enum TradingError: Error {
        case customError(description: String)
    }
    
    private let stablesSet: Set<String> = Set(arrayLiteral: "BUSD", "USDT", "USDC", "TUSD")
    private let allowedAssetsToTrade: Set<String> = Set(arrayLiteral: "BUSD", "USDT", "USDC", "TUSD", "BTC", "ETH", "BNB", "UAH")
    private let forbiddenAssetsToTrade: Set<String> = Set(arrayLiteral: "RUB")
    
    private var tradeableSymbolsDict: [String: BinanceAPIService.Symbol] = [:]
    private var approximateBookTickers: [String: BookTicker] = [:]
    
    private let minimumQuantityMultipler: Double = 2
    private let minimumQuantityStableEquivalent: Double
    private let maximalDifferencePercent = 0.2
    
    init() {
        minimumQuantityStableEquivalent = 10.0 * minimumQuantityMultipler
        
        Jobs.add(interval: .seconds(7200)) { [weak self] in
            BinanceAPIService.shared.getExchangeInfo { [weak self] symbols in
                guard let symbols = symbols else { return }
                
                let tradeableSymbols = symbols.filter { $0.status == .trading && $0.isSpotTradingAllowed }
                
                self?.tradeableSymbolsDict = tradeableSymbols.toDictionary(with: { $0.symbol })
            }
        }
        
        Jobs.add(interval: .seconds(600)) {
            BinanceAPIService.shared.getAllBookTickers { [weak self] tickers in
                guard let tickers = tickers else { return }
                
                self?.approximateBookTickers = tickers.toDictionary(with: { $0.symbol })
            }
        }
    
    }
    
    // MARK: - Depth Check
    
    func handle(
        triangularOpportunity: TriangularOpportunity,
        for userInfo: UserInfo
    ) async throws -> TriangularOpportunity {
        switch triangularOpportunity.autotradeCicle {
        case .pending:
            // NOTE: - remove handling only first - handle all of opportunities
            guard allowedAssetsToTrade.contains(triangularOpportunity.firstSurfaceResult.swap0),
                  forbiddenAssetsToTrade.contains(triangularOpportunity.firstSurfaceResult.swap0) == false,
                  forbiddenAssetsToTrade.contains(triangularOpportunity.firstSurfaceResult.swap1) == false,
                  forbiddenAssetsToTrade.contains(triangularOpportunity.firstSurfaceResult.swap2) == false else {
                triangularOpportunity.autotradeCicle = .forbidden
                triangularOpportunity.autotradeLog.append("Not tradeable opportunity\n")
                return triangularOpportunity
            }
            
            guard let lastSurfaceResult = triangularOpportunity.surfaceResults.last else {
                triangularOpportunity.autotradeCicle = .forbidden
                triangularOpportunity.autotradeLog.append("no last result..")
                return triangularOpportunity
            }
            
            do {
                let depth = try await getDepth(for: lastSurfaceResult, limit: 5)
                
                let trade1Quantity = try getFirstTradeQuantity(for: triangularOpportunity)
                let trade1AveragePrice = depth.pairADepth.getProbableDepthPrice(
                    for: lastSurfaceResult.directionTrade1,
                    amount: trade1Quantity * 10 // to be sure our amount exist
                )
                let trade1PriceDifferencePercent = (trade1AveragePrice - lastSurfaceResult.pairAExpectedPrice) / lastSurfaceResult.pairAExpectedPrice * 100.0
                guard abs(trade1PriceDifferencePercent) <= self.maximalDifferencePercent else {
                    triangularOpportunity.autotradeLog.append("\nTrade 1 price: \(trade1AveragePrice.string()) (\(trade1PriceDifferencePercent.string(maxFractionDigits: 4))% diff)\n")
                    return triangularOpportunity
                }
                
                let trade2ApproximateQuantity = trade1Quantity * lastSurfaceResult.swap2Rate
                let trade2AveragePrice = depth.pairBDepth.getProbableDepthPrice(
                    for: lastSurfaceResult.directionTrade2,
                    amount: trade2ApproximateQuantity * 10 // Extra
                )
                let trade2PriceDifferencePercent = (trade2AveragePrice - lastSurfaceResult.pairBExpectedPrice) / lastSurfaceResult.pairBExpectedPrice * 100.0
                guard abs(trade2PriceDifferencePercent) <= self.maximalDifferencePercent else {
                    triangularOpportunity.autotradeLog.append("\nTrade 2 price: \(trade2AveragePrice.string(maxFractionDigits: 5)) (\(trade2PriceDifferencePercent.string(maxFractionDigits: 4))% diff)\n")
                    return triangularOpportunity
                }
                
                let trade3ApproximateQuantity = trade2ApproximateQuantity * lastSurfaceResult.swap3Rate
                let trade3AveragePrice = depth.pairCDepth.getProbableDepthPrice(
                    for: lastSurfaceResult.directionTrade3,
                    amount: trade3ApproximateQuantity * 10
                )
                let trade3PriceDifferencePercent = (trade3AveragePrice - lastSurfaceResult.pairCExpectedPrice) / lastSurfaceResult.pairCExpectedPrice * 100.0
                guard abs(trade3PriceDifferencePercent) <= self.maximalDifferencePercent else {
                    triangularOpportunity.autotradeLog.append("\nTrade 3 price: \(trade3AveragePrice.string()) (\(trade3PriceDifferencePercent.string(maxFractionDigits: 4))% diff)\n")
                    return triangularOpportunity
                }
                
                return try await handleFirstTrade(for: triangularOpportunity, quantityToExequte: trade1Quantity)
            } catch TradingError.customError(let description) {
                triangularOpportunity.autotradeCicle = .forbidden
                triangularOpportunity.autotradeLog.append(description)
                return triangularOpportunity
            } catch BinanceError.unexpected(let description) {
                triangularOpportunity.autotradeCicle = .forbidden
                triangularOpportunity.autotradeLog.append(description)
                return triangularOpportunity
            } catch {
                triangularOpportunity.autotradeCicle = .forbidden
                triangularOpportunity.autotradeLog.append(error.localizedDescription)
                return triangularOpportunity
            }
            
        default:
            return triangularOpportunity
        }
    }

    // MARK: - Get depth
    
    private func getDepth(for surfaceResult: SurfaceResult, limit: UInt) async throws -> TriangularOpportunityDepth {
        async let pairADepthData = BinanceAPIService.shared.getOrderbookDepth(symbol: surfaceResult.contract1, limit: limit)
        async let pairBDepthData = BinanceAPIService.shared.getOrderbookDepth(symbol: surfaceResult.contract2, limit: limit)
        async let pairCDepthData = BinanceAPIService.shared.getOrderbookDepth(symbol: surfaceResult.contract3, limit: limit)
        
        let (pairADepth, pairBDepth, pairCDepth) = try await (pairADepthData, pairBDepthData, pairCDepthData)
        return TriangularOpportunityDepth(pairADepth: pairADepth, pairBDepth: pairBDepth, pairCDepth: pairCDepth)
    }
    
    // MARK: - First Trade
    
    private func getFirstTradeQuantity(for opportunity: TriangularOpportunity) throws -> Double {
        guard let firstSymbolDetails = tradeableSymbolsDict[opportunity.firstSurfaceResult.contract1] else {
            throw TradingError.customError(description: "\nError: No contract1 at tradeable symbols")
        }
        
        guard let firstOrderMinNotionalString = firstSymbolDetails.filters.first(where: { $0.filterType == .minNotional })?.minNotional,
              let firstOrderMinNotional = Double(firstOrderMinNotionalString)
        else {
            throw TradingError.customError(description: "\nError: No min notional")
        }
        
        guard let approximateTickerPrice = approximateBookTickers[opportunity.firstSurfaceResult.contract1]?.buyPrice else {
            throw TradingError.customError(description: "No approximate ticker price")
        }
        
        let preferableQuantityForFirstTrade: Double
        switch opportunity.firstSurfaceResult.directionTrade1 {
        case .baseToQuote:
            let minNotionalEquivalentQuantity = firstOrderMinNotional * minimumQuantityMultipler / approximateTickerPrice
            if let minStableEquivalentQuantity = getApproximateMinimalPortion(for: opportunity.firstSurfaceResult.swap0) {
                preferableQuantityForFirstTrade = max(minNotionalEquivalentQuantity, minStableEquivalentQuantity)
            } else {
                preferableQuantityForFirstTrade = minNotionalEquivalentQuantity
            }
        case .quoteToBase:
            let minNotionalEquivalentQuantity = firstOrderMinNotional * minimumQuantityMultipler
            if let minStableEquivalentQuantity = getApproximateMinimalPortion(for: opportunity.firstSurfaceResult.swap0) {
                preferableQuantityForFirstTrade = max(minNotionalEquivalentQuantity, minStableEquivalentQuantity)
            } else {
                preferableQuantityForFirstTrade = minNotionalEquivalentQuantity
            }
        case .unknown:
            throw TradingError.customError(description: "Unknown side")
        }
        
        guard let lotSizeMinQtyString = firstSymbolDetails.filters.first(where: { $0.filterType == .lotSize })?.minQty,
              let lotSizeMinQty = Double(lotSizeMinQtyString) else {
            throw TradingError.customError(description: "No Lot_Size for \(opportunity.firstSurfaceResult.contract2)")
        }
        
        let leftoversAfterRounding = preferableQuantityForFirstTrade.truncatingRemainder(dividingBy: lotSizeMinQty)
        let quantityToExequte = (preferableQuantityForFirstTrade - leftoversAfterRounding).roundToDecimal(8)
        
        guard quantityToExequte > 0 else {
            opportunity.autotradeCicle = .forbidden
            throw TradingError.customError(description: "Quantity to Qxecute is 0 - have to have bigger amount")
        }
        
        return quantityToExequte
    }
    
    private func handleFirstTrade(
        for opportunityToTrade: TriangularOpportunity,
        quantityToExequte: Double
    ) async throws -> TriangularOpportunity {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        opportunityToTrade.autotradeCicle = .firstTradeStarted
        
        let firstOrderResponse = try await BinanceAPIService.shared.newOrder(
            symbol: opportunityToTrade.firstSurfaceResult.contract1,
            side: opportunityToTrade.firstSurfaceResult.directionTrade1,
            type: .market,
            quantity: quantityToExequte,
            quoteOrderQty: quantityToExequte,
            newOrderRespType: .full
        )
        
        opportunityToTrade.autotradeCicle = .firstTradeFinished
        let description = self.getComparableDescription(for: firstOrderResponse, expectedExecutionPrice: opportunityToTrade.firstSurfaceResult.pairAExpectedPrice)
        opportunityToTrade.autotradeLog.append("\nStep 1: \(description)")
        
        let commission: Double = self.getCommissionStableEquivalent(for: firstOrderResponse.fills)
        if commission > 0 {
            opportunityToTrade.autotradeLog.append("\nCommission: ≈\(commission.string(maxFractionDigits: 4))")
        }
        
        let usedCapital: Double
        let preferableQuantityForSecondTrade: Double
        switch opportunityToTrade.firstSurfaceResult.directionTrade1 {
        case .quoteToBase:
            usedCapital = Double(firstOrderResponse.cummulativeQuoteQty) ?? 0.0
            preferableQuantityForSecondTrade = Double(firstOrderResponse.executedQty) ?? 0.0
        case .baseToQuote:
            usedCapital = Double(firstOrderResponse.executedQty) ?? 0.0
            preferableQuantityForSecondTrade = Double(firstOrderResponse.cummulativeQuoteQty) ?? 0.0
        case .unknown:
            usedCapital = 0
            preferableQuantityForSecondTrade = 0
        }
                
        return try await handleSecondTrade(
            for: opportunityToTrade,
            usedCapital: usedCapital,
            firstOrderComission: commission,
            preferableQuantityToExecute: preferableQuantityForSecondTrade,
            startTime: startTime
        )
    }
    // MARK: - Second Trade
    
    private func handleSecondTrade(
        for opportunityToTrade: TriangularOpportunity,
        usedCapital: Double,
        firstOrderComission: Double,
        preferableQuantityToExecute: Double,
        startTime: CFAbsoluteTime
    ) async throws -> TriangularOpportunity {
        opportunityToTrade.autotradeCicle = .secondTradeStarted
        
        guard let secondSymbolDetails = tradeableSymbolsDict[opportunityToTrade.firstSurfaceResult.contract2],
              let lotSizeMinQtyString = secondSymbolDetails.filters.first(where: { $0.filterType == .lotSize })?.minQty,
              let lotSizeMinQty = Double(lotSizeMinQtyString),
              let tickSizeString = secondSymbolDetails.filters.first(where: { $0.filterType == .priceFilter })?.tickSize,
              let tickSize = Double(tickSizeString)
        else {
            throw TradingError.customError(description:"No Lot_Size for \(opportunityToTrade.firstSurfaceResult.contract2)")
        }
        
        let precisionDivider: Double
        switch opportunityToTrade.firstSurfaceResult.directionTrade2 {
        case .quoteToBase:
            precisionDivider = tickSize
        case .baseToQuote:
            precisionDivider = lotSizeMinQty
        case .unknown:
            precisionDivider = 1.0
        }
        
        let leftoversAfterRounding = preferableQuantityToExecute.truncatingRemainder(dividingBy: precisionDivider)
        var leftoversAfterRoundingStableEquivalent = 0.0
        if leftoversAfterRounding > 0 {
            leftoversAfterRoundingStableEquivalent = self.getApproximatesStableEquivalent(asset: opportunityToTrade.firstSurfaceResult.swap1, assetQuantity: leftoversAfterRounding) ?? 0.0
            opportunityToTrade.autotradeLog.append("\n\nLeftovers before second trade: \(leftoversAfterRounding.string(maxFractionDigits: 8)) \(opportunityToTrade.firstSurfaceResult.swap1) ≈ \(leftoversAfterRoundingStableEquivalent.string(maxFractionDigits: 4)) USDT")
        }
        
        let quantityToExequte = (preferableQuantityToExecute - leftoversAfterRounding).roundToDecimal(8)
        opportunityToTrade.autotradeLog.append("\nQuantity to execute on second trade: \(quantityToExequte) \(opportunityToTrade.firstSurfaceResult.swap1)")
        let secondOrderResponse = try await BinanceAPIService.shared.newOrder(
            symbol: opportunityToTrade.firstSurfaceResult.contract2,
            side: opportunityToTrade.firstSurfaceResult.directionTrade2,
            type: .market,
            quantity: quantityToExequte,
            quoteOrderQty: quantityToExequte,
            newOrderRespType: .full
        )
        
        opportunityToTrade.autotradeCicle = .secondTradeFinished
        let description = self.getComparableDescription(for: secondOrderResponse, expectedExecutionPrice: opportunityToTrade.firstSurfaceResult.pairBExpectedPrice)
        opportunityToTrade.autotradeLog.append("\n\nStep 2: \(description)")
        
        let secondOrderComission: Double = self.getCommissionStableEquivalent(for: secondOrderResponse.fills)
        if secondOrderComission > 0 {
            opportunityToTrade.autotradeLog.append("\nCommission: ≈ \(secondOrderComission.string(maxFractionDigits: 4)) USDT")
        }
        
        let usedAssetQuantity: Double
        let preferableQuantityFotThirdTrade: Double
        switch opportunityToTrade.firstSurfaceResult.directionTrade2 {
        case .quoteToBase:
            usedAssetQuantity = Double(secondOrderResponse.cummulativeQuoteQty) ?? 0.0
            preferableQuantityFotThirdTrade = Double(secondOrderResponse.executedQty) ?? 0.0
        case .baseToQuote:
            usedAssetQuantity = Double(secondOrderResponse.executedQty) ?? 0.0
            preferableQuantityFotThirdTrade = Double(secondOrderResponse.cummulativeQuoteQty) ?? 0.0
        case .unknown:
            usedAssetQuantity = 0
            preferableQuantityFotThirdTrade = 0
        }
        
        let leftovers = quantityToExequte - usedAssetQuantity
        var approximatesStableEquivalentLeftover: Double = 0.0
        if leftovers > 0 {
            approximatesStableEquivalentLeftover = self.getApproximatesStableEquivalent(asset: opportunityToTrade.firstSurfaceResult.swap1, assetQuantity: leftovers) ?? 0.0
            opportunityToTrade.autotradeLog.append("\nLeftovers: \(leftovers.string(maxFractionDigits: 8)) \(opportunityToTrade.firstSurfaceResult.swap1) \(self.getApproximateStableEquivalentDescription(asset: opportunityToTrade.firstSurfaceResult.swap1, quantity: leftovers) ?? "")")
        }
        
        return try await handleThirdTrade(
            for: opportunityToTrade,
            usedCapital: usedCapital,
            commissions: firstOrderComission + secondOrderComission,
            preferableQuantityToExecute: preferableQuantityFotThirdTrade,
            startTime: startTime,
            secondTradeStableLeftovers: leftoversAfterRoundingStableEquivalent + approximatesStableEquivalentLeftover
        )
    }
    
    // MARK: - Third Trade
    
    private func handleThirdTrade(
        for opportunityToTrade: TriangularOpportunity,
        usedCapital: Double,
        commissions: Double,
        preferableQuantityToExecute: Double,
        startTime: CFAbsoluteTime,
        secondTradeStableLeftovers: Double // USDT
    ) async throws -> TriangularOpportunity {
        opportunityToTrade.autotradeCicle = .thirdTradeStarted
        
        guard let thirdSymbolDetails = tradeableSymbolsDict[opportunityToTrade.firstSurfaceResult.contract3],
              let lotSizeMinQtyString = thirdSymbolDetails.filters.first(where: { $0.filterType == .lotSize })?.minQty,
              let lotSizeMinQty = Double(lotSizeMinQtyString),
              let tickSizeString = thirdSymbolDetails.filters.first(where: { $0.filterType == .priceFilter })?.tickSize,
              let tickSize = Double(tickSizeString)
        else {
            throw TradingError.customError(description: "No Lot_Size for \(opportunityToTrade.firstSurfaceResult.contract3)")
        }
        
        let precisionDivider: Double
        switch opportunityToTrade.firstSurfaceResult.directionTrade3 {
        case .quoteToBase:
            precisionDivider = tickSize
        case .baseToQuote:
            precisionDivider = lotSizeMinQty
        case .unknown:
            precisionDivider = 1.0
        }
        
        let leftoversAfterRounding = preferableQuantityToExecute.truncatingRemainder(dividingBy: precisionDivider)
        var leftoversAfterRoundingStableEquivalent: Double = 0.0
        if leftoversAfterRounding > 0 {
            leftoversAfterRoundingStableEquivalent = self.getApproximatesStableEquivalent(asset: opportunityToTrade.firstSurfaceResult.swap2, assetQuantity: leftoversAfterRounding) ?? 0.0
            opportunityToTrade.autotradeLog.append("\n\nLeftovers before third trade: \(leftoversAfterRounding.string(maxFractionDigits: 8)) \(opportunityToTrade.firstSurfaceResult.swap2) ≈ \(leftoversAfterRoundingStableEquivalent.string(maxFractionDigits: 4)) USDT")
        }
        
        let quantityToExequte = (preferableQuantityToExecute - leftoversAfterRounding).roundToDecimal(8)
        opportunityToTrade.autotradeLog.append("\nQuantity to execute on third trade: \(quantityToExequte) \(opportunityToTrade.firstSurfaceResult.swap2)")
        let thirdOrderResponse = try await BinanceAPIService.shared.newOrder(
            symbol: opportunityToTrade.firstSurfaceResult.contract3,
            side: opportunityToTrade.firstSurfaceResult.directionTrade3,
            type: .market,
            quantity: quantityToExequte,
            quoteOrderQty: quantityToExequte,
            newOrderRespType: .full
        )
        
        let description = self.getComparableDescription(for: thirdOrderResponse, expectedExecutionPrice: opportunityToTrade.firstSurfaceResult.pairCExpectedPrice)
        opportunityToTrade.autotradeCicle = .thirdTradeFinished(result: description)
        opportunityToTrade.autotradeLog.append("\n\nStep 3: \(description)")
        
        let thirdOrderComission: Double = self.getCommissionStableEquivalent(for: thirdOrderResponse.fills)
        if thirdOrderComission > 0 {
            opportunityToTrade.autotradeLog.append("\nCommission: \(thirdOrderComission.string(maxFractionDigits: 4)) USDT")
        }
        
        let usedAssetQuantity: Double
        let actualResultingAmount: Double
        switch opportunityToTrade.firstSurfaceResult.directionTrade3 {
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
        
        let thirdTradeLeftovers = quantityToExequte - usedAssetQuantity
        if thirdTradeLeftovers > 0 {
            opportunityToTrade.autotradeLog.append("\nLeftovers: \((quantityToExequte - usedAssetQuantity).string(maxFractionDigits: 8)) \(opportunityToTrade.firstSurfaceResult.swap2) \(self.getApproximateStableEquivalentDescription(asset: opportunityToTrade.firstSurfaceResult.swap2, quantity: quantityToExequte - usedAssetQuantity) ?? "")")
        }
        
        let duration = String(format: "%.4f", CFAbsoluteTimeGetCurrent() - startTime)
        opportunityToTrade.autotradeLog.append("\n\nCicle trading time: \(duration)s")
        
        let totalComission = commissions + thirdOrderComission
        if totalComission > 0 {
            opportunityToTrade.autotradeLog.append("\nTotal comission: ≈ \(totalComission.string(maxFractionDigits: 4)) USDT")
        }
        
        let thirdTradeStableEquivalentLeftover = self.getApproximatesStableEquivalent(asset: opportunityToTrade.firstSurfaceResult.swap2, assetQuantity: thirdTradeLeftovers) ?? 0.0
        let totalStableEquivalentLeftover = secondTradeStableLeftovers + leftoversAfterRoundingStableEquivalent + thirdTradeStableEquivalentLeftover
        if totalStableEquivalentLeftover > 0.0 {
            opportunityToTrade.autotradeLog.append("\nTotal leftovers: ≈ \(totalStableEquivalentLeftover.string(maxFractionDigits: 6)) USDT")
        }
        
        opportunityToTrade.autotradeLog.append("\nUsed Capital: \(usedCapital) | Actual Resulting Amount: \(actualResultingAmount)")
        
        let usedCapitalStableEquivalent = self.getApproximatesStableEquivalent(asset: opportunityToTrade.firstSurfaceResult.swap0, assetQuantity: usedCapital) ?? 0.0
        let actualResultingAmountStableEquivalent = self.getApproximatesStableEquivalent(asset: opportunityToTrade.firstSurfaceResult.swap0, assetQuantity: actualResultingAmount) ?? 0.0
        
        let profit: Double = actualResultingAmountStableEquivalent + totalStableEquivalentLeftover - usedCapitalStableEquivalent - commissions
        opportunityToTrade.autotradeLog.append("\nActual Profit: ≈ \(profit.string(maxFractionDigits: 4)) USDT")
        opportunityToTrade.autotradeLog.append(" | \((profit / usedCapitalStableEquivalent * 100.0).string(maxFractionDigits: 4))%")
        return opportunityToTrade
    }
    
}

// MARK: - Helpers

private extension AutoTradingService {
    
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
    
    func getApproximateMinimalPortion(for asset: String) -> Double? {
        if let approximatesStableEquivalent = getApproximatesStableEquivalent(asset: asset, assetQuantity: 1) {
            return minimumQuantityStableEquivalent / approximatesStableEquivalent
        } else {
            return nil
        }
    }
    
    func getApproximateStableEquivalentDescription(asset: String, quantity: Double) -> String? {
        if let approximatesStableEquivalent = getApproximatesStableEquivalent(asset: asset, assetQuantity: quantity) {
            return " ≈ \(approximatesStableEquivalent.string(maxFractionDigits: 4)) USDT"
        } else {
            return nil
        }
    }
    
    
    func getCommissionStableEquivalent(for fills: [BinanceAPIService.Fill]) -> Double {
        fills.map { fill in
            if let commission = Double(fill.commission), let approximatesStableEquivalent = getApproximatesStableEquivalent(asset: fill.commissionAsset, assetQuantity: commission) {
                return approximatesStableEquivalent
            } else {
                return 0
            }
        }.reduce(0, { x, y in x + y })
    }
    
    func getApproximatesStableEquivalent(asset: String, assetQuantity: Double) -> Double? {
        guard stablesSet.contains(asset) == false else { return assetQuantity }
        
        if let assetToStableSymbol = approximateBookTickers["\(asset)USDT"], let assetToStableApproximatePrice = assetToStableSymbol.sellPrice {
            return assetQuantity * assetToStableApproximatePrice
        } else if let stableToAssetSymbol = approximateBookTickers["USDT\(asset)"], let stableToAssetApproximatePrice = stableToAssetSymbol.buyPrice {
            return assetQuantity / stableToAssetApproximatePrice
        } else {
            return nil
        }
    }
    
}
