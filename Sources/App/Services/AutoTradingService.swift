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
        case noMinimalPortion(description: String)
        case customError(description: String)
    }
    
    private let stablesSet: Set<String> = Set(arrayLiteral: "BUSD", "USDT", "USDC", "TUSD")
    private let allowedAssetsToTrade: Set<String> = Set(arrayLiteral: "BUSD", "USDT", "USDC", "TUSD", "BTC", "ETH", "BNB", "UAH")
    private let forbiddenAssetsToTrade: Set<String> = Set(arrayLiteral: "RUB")
    
    private var tradeableSymbolsDict: [String: BinanceAPIService.Symbol] = [:]
    private var approximateBookTickers: [String: BookTicker] = [:]
    
    private let minimumQuantityMultipler: Double = 1.5
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
        opportunity: TriangularOpportunity,
        for userInfo: UserInfo
    ) async throws -> TriangularOpportunity {
        switch opportunity.autotradeCicle {
        case .pending:
            
            opportunity.autotradeCicle = .depthCheck
            // NOTE: - remove handling only first - handle all of opportunities
            guard allowedAssetsToTrade.contains(opportunity.firstSurfaceResult.swap0),
                  forbiddenAssetsToTrade.contains(opportunity.firstSurfaceResult.swap0) == false,
                  forbiddenAssetsToTrade.contains(opportunity.firstSurfaceResult.swap1) == false,
                  forbiddenAssetsToTrade.contains(opportunity.firstSurfaceResult.swap2) == false else {
                opportunity.autotradeCicle = .forbidden
                opportunity.autotradeLog.append("Not tradeable opportunity\n")
                return opportunity
            }
            
            guard let lastSurfaceResult = opportunity.surfaceResults.last else {
                opportunity.autotradeCicle = .forbidden
                opportunity.autotradeLog.append("no last result..")
                return opportunity
            }
            
            do {
                let depth = try await getDepth(for: lastSurfaceResult, limit: 10)
                
                let trade1ApproximateOrderbookQuantity = try getApproximateMinimalAssetPortionToReceive(contract: lastSurfaceResult.contract1, asset: lastSurfaceResult.swap0)
                let trade1AveragePrice = depth.pairADepth.getProbableDepthPrice(
                    for: lastSurfaceResult.directionTrade1,
                    amount: trade1ApproximateOrderbookQuantity * 3 // to be sure our amount exist
                )
                let trade1PriceDifferencePercent = (trade1AveragePrice - lastSurfaceResult.pairAExpectedPrice) / lastSurfaceResult.pairAExpectedPrice * 100.0
                guard abs(trade1PriceDifferencePercent) <= self.maximalDifferencePercent else {
                    opportunity.autotradeLog.append("\nTrade 1 price: \(trade1AveragePrice.string()) (\(trade1PriceDifferencePercent.string(maxFractionDigits: 4))% diff)\n")
                    opportunity.autotradeCicle = .pending
                    return opportunity
                }
                
                let trade2ApproximateOrderbookQuantity = try getApproximateMinimalAssetPortionToReceive(contract: lastSurfaceResult.contract2, asset: lastSurfaceResult.swap1)
                let trade2AveragePrice = depth.pairBDepth.getProbableDepthPrice(
                    for: lastSurfaceResult.directionTrade2,
                    amount: trade2ApproximateOrderbookQuantity * 5 // Extra
                )
                let trade2PriceDifferencePercent = (trade2AveragePrice - lastSurfaceResult.pairBExpectedPrice) / lastSurfaceResult.pairBExpectedPrice * 100.0
                guard abs(trade2PriceDifferencePercent) <= self.maximalDifferencePercent else {
                    opportunity.autotradeLog.append("\nTrade 2 price: \(trade2AveragePrice.string(maxFractionDigits: 5)) (\(trade2PriceDifferencePercent.string(maxFractionDigits: 4))% diff)\n")
                    opportunity.autotradeCicle = .pending
                    return opportunity
                }
                
                let trade3ApproximateOrderbookQuantity = try getApproximateMinimalAssetPortionToReceive(contract: lastSurfaceResult.contract3, asset: lastSurfaceResult.swap2)
                let trade3AveragePrice = depth.pairCDepth.getProbableDepthPrice(
                    for: lastSurfaceResult.directionTrade3,
                    amount: trade3ApproximateOrderbookQuantity * 7
                )
                let trade3PriceDifferencePercent = (trade3AveragePrice - lastSurfaceResult.pairCExpectedPrice) / lastSurfaceResult.pairCExpectedPrice * 100.0
                guard abs(trade3PriceDifferencePercent) <= self.maximalDifferencePercent else {
                    opportunity.autotradeLog.append("\nTrade 3 price: \(trade3AveragePrice.string()) (\(trade3PriceDifferencePercent.string(maxFractionDigits: 4))% diff)\n")
                    opportunity.autotradeCicle = .pending
                    return opportunity
                }
                
                return try await handleFirstTrade(for: opportunity)
            } catch TradingError.noMinimalPortion(let description) {
                opportunity.autotradeCicle = .forbidden
                opportunity.autotradeLog.append(description)
                return opportunity
            } catch TradingError.customError(let description) {
                opportunity.autotradeCicle = .forbidden
                opportunity.autotradeLog.append(description)
                return opportunity
            } catch BinanceError.unexpected(let description) {
                opportunity.autotradeCicle = .forbidden
                opportunity.autotradeLog.append(description)
                
                // NOTE: - handle email sending
                try await EmailAPIService.shared.sendEmail(with: .init(
                    personalizations: [.init(to: [.init(email: "ruslanpopesku95@gmail.com")])],
                    from: .init(email: "ruslanpopesku95@gmail.com"),
                    subject: "Binance Error: \(description)",
                    content: [.init(type: "test type", value: description)]
                ))
                
                return opportunity
            } catch {
                opportunity.autotradeCicle = .pending
                opportunity.autotradeLog.append(error.localizedDescription)
                return opportunity
            }
            
        default:
            return opportunity
        }
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
            let minStableEquivalentQuantity = try getApproximateMinimalPortion(for: opportunity.firstSurfaceResult.swap0)
            preferableQuantityForFirstTrade = max(minNotionalEquivalentQuantity, minStableEquivalentQuantity)
        case .quoteToBase:
            let minNotionalEquivalentQuantity = firstOrderMinNotional * minimumQuantityMultipler
            let minStableEquivalentQuantity = try getApproximateMinimalPortion(for: opportunity.firstSurfaceResult.swap0)
            preferableQuantityForFirstTrade = max(minNotionalEquivalentQuantity, minStableEquivalentQuantity)
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
    
    private func handleFirstTrade(for opportunity: TriangularOpportunity) async throws -> TriangularOpportunity {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let trade1Quantity = try getFirstTradeQuantity(for: opportunity)
        opportunity.autotradeCicle = .trading
        
        let firstOrderResponse = try await BinanceAPIService.shared.newOrder(
            symbol: opportunity.firstSurfaceResult.contract1,
            side: opportunity.firstSurfaceResult.directionTrade1,
            type: .market,
            quantity: trade1Quantity,
            quoteOrderQty: trade1Quantity,
            newOrderRespType: .full
        )
        
        opportunity.autotradeCicle = .trading
        let description = self.getComparableDescription(for: firstOrderResponse, expectedExecutionPrice: opportunity.firstSurfaceResult.pairAExpectedPrice)
        opportunity.autotradeLog.append("\nStep 1: \(description)")
        
        let commission: Double = try getCommissionStableEquivalent(for: firstOrderResponse.fills)
        if commission > 0 {
            opportunity.autotradeLog.append("\nCommission: ≈\(commission.string(maxFractionDigits: 4))")
        }
        
        let duration = String(format: "%.4f", CFAbsoluteTimeGetCurrent() - startTime)
        opportunity.autotradeLog.append("First trade time: \(duration)s")
        
        let usedCapital: Double
        let preferableQuantityForSecondTrade: Double
        switch opportunity.firstSurfaceResult.directionTrade1 {
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
            for: opportunity,
            usedCapital: usedCapital,
            firstOrderComission: commission,
            preferableQuantityToExecute: preferableQuantityForSecondTrade
        )
    }
    // MARK: - Second Trade
    
    private func handleSecondTrade(
        for opportunity: TriangularOpportunity,
        usedCapital: Double,
        firstOrderComission: Double,
        preferableQuantityToExecute: Double
    ) async throws -> TriangularOpportunity {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        guard let secondSymbolDetails = tradeableSymbolsDict[opportunity.firstSurfaceResult.contract2],
              let lotSizeMinQtyString = secondSymbolDetails.filters.first(where: { $0.filterType == .lotSize })?.minQty,
              let lotSizeMinQty = Double(lotSizeMinQtyString),
              let tickSizeString = secondSymbolDetails.filters.first(where: { $0.filterType == .priceFilter })?.tickSize,
              let tickSize = Double(tickSizeString)
        else {
            throw TradingError.customError(description:"No Lot_Size for \(opportunity.firstSurfaceResult.contract2)")
        }
        
        let precisionDivider: Double
        switch opportunity.firstSurfaceResult.directionTrade2 {
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
            leftoversAfterRoundingStableEquivalent = try getApproximatesStableEquivalent(asset: opportunity.firstSurfaceResult.swap1, assetQuantity: leftoversAfterRounding)
            opportunity.autotradeLog.append("\n\nLeftovers before second trade: \(leftoversAfterRounding.string(maxFractionDigits: 8)) \(opportunity.firstSurfaceResult.swap1) ≈ \(leftoversAfterRoundingStableEquivalent.string(maxFractionDigits: 4)) USDT")
        }
        
        let quantityToExequte = (preferableQuantityToExecute - leftoversAfterRounding).roundToDecimal(8)
        opportunity.autotradeLog.append("\nQuantity to execute on second trade: \(quantityToExequte) \(opportunity.firstSurfaceResult.swap1)")
        let secondOrderResponse = try await BinanceAPIService.shared.newOrder(
            symbol: opportunity.firstSurfaceResult.contract2,
            side: opportunity.firstSurfaceResult.directionTrade2,
            type: .market,
            quantity: quantityToExequte,
            quoteOrderQty: quantityToExequte,
            newOrderRespType: .full
        )
        let description = getComparableDescription(for: secondOrderResponse, expectedExecutionPrice: opportunity.firstSurfaceResult.pairBExpectedPrice)
        opportunity.autotradeLog.append("\n\nStep 2: \(description)")
        
        let secondOrderComission: Double = try getCommissionStableEquivalent(for: secondOrderResponse.fills)
        if secondOrderComission > 0 {
            opportunity.autotradeLog.append("\nCommission: ≈ \(secondOrderComission.string(maxFractionDigits: 4)) USDT")
        }
        
        let usedAssetQuantity: Double
        let preferableQuantityFotThirdTrade: Double
        switch opportunity.firstSurfaceResult.directionTrade2 {
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
            approximatesStableEquivalentLeftover = try getApproximatesStableEquivalent(asset: opportunity.firstSurfaceResult.swap1, assetQuantity: leftovers)
            opportunity.autotradeLog.append("\nLeftovers: \(leftovers.string(maxFractionDigits: 8)) \(opportunity.firstSurfaceResult.swap1) \(try getApproximateStableEquivalentDescription(asset: opportunity.firstSurfaceResult.swap1, quantity: leftovers) )")
        }
        
        let duration = String(format: "%.4f", CFAbsoluteTimeGetCurrent() - startTime)
        opportunity.autotradeLog.append("\nSecond trade time: \(duration)s")
        
        return try await handleThirdTrade(
            for: opportunity,
            usedCapital: usedCapital,
            commissions: firstOrderComission + secondOrderComission,
            preferableQuantityToExecute: preferableQuantityFotThirdTrade,
            secondTradeStableLeftovers: leftoversAfterRoundingStableEquivalent + approximatesStableEquivalentLeftover
        )
    }
    
    // MARK: - Third Trade
    
    private func handleThirdTrade(
        for opportunity: TriangularOpportunity,
        usedCapital: Double,
        commissions: Double,
        preferableQuantityToExecute: Double,
        secondTradeStableLeftovers: Double // USDT
    ) async throws -> TriangularOpportunity {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        guard let thirdSymbolDetails = tradeableSymbolsDict[opportunity.firstSurfaceResult.contract3],
              let lotSizeMinQtyString = thirdSymbolDetails.filters.first(where: { $0.filterType == .lotSize })?.minQty,
              let lotSizeMinQty = Double(lotSizeMinQtyString),
              let tickSizeString = thirdSymbolDetails.filters.first(where: { $0.filterType == .priceFilter })?.tickSize,
              let tickSize = Double(tickSizeString)
        else {
            throw TradingError.customError(description: "No Lot_Size for \(opportunity.firstSurfaceResult.contract3)")
        }
        
        let precisionDivider: Double
        switch opportunity.firstSurfaceResult.directionTrade3 {
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
            leftoversAfterRoundingStableEquivalent = try getApproximatesStableEquivalent(asset: opportunity.firstSurfaceResult.swap2, assetQuantity: leftoversAfterRounding)
            opportunity.autotradeLog.append("\n\nLeftovers before third trade: \(leftoversAfterRounding.string(maxFractionDigits: 8)) \(opportunity.firstSurfaceResult.swap2) ≈ \(leftoversAfterRoundingStableEquivalent.string(maxFractionDigits: 4)) USDT")
        }
        
        let quantityToExequte = (preferableQuantityToExecute - leftoversAfterRounding).roundToDecimal(8)
        opportunity.autotradeLog.append("\nQuantity to execute on third trade: \(quantityToExequte) \(opportunity.firstSurfaceResult.swap2)")
        let thirdOrderResponse = try await BinanceAPIService.shared.newOrder(
            symbol: opportunity.firstSurfaceResult.contract3,
            side: opportunity.firstSurfaceResult.directionTrade3,
            type: .market,
            quantity: quantityToExequte,
            quoteOrderQty: quantityToExequte,
            newOrderRespType: .full
        )
        
        let description = self.getComparableDescription(for: thirdOrderResponse, expectedExecutionPrice: opportunity.firstSurfaceResult.pairCExpectedPrice)
        opportunity.autotradeCicle = .completed
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
        
        let thirdTradeLeftovers = quantityToExequte - usedAssetQuantity
        if thirdTradeLeftovers > 0 {
            let stableEquivalent = try getApproximateStableEquivalentDescription(asset: opportunity.firstSurfaceResult.swap2, quantity: quantityToExequte - usedAssetQuantity)
            opportunity.autotradeLog.append("\nLeftovers: \((quantityToExequte - usedAssetQuantity).string(maxFractionDigits: 8)) \(opportunity.firstSurfaceResult.swap2) \(stableEquivalent)")
        }
        
        
        let duration = String(format: "%.4f", CFAbsoluteTimeGetCurrent() - startTime)
        opportunity.autotradeLog.append("\nThird trade time: \(duration)s")
        
        let totalComission = commissions + thirdOrderComission
        if totalComission > 0 {
            opportunity.autotradeLog.append("\n\nTotal comission: ≈ \(totalComission.string(maxFractionDigits: 4)) USDT")
        }
        
        let thirdTradeStableEquivalentLeftover = try getApproximatesStableEquivalent(asset: opportunity.firstSurfaceResult.swap2, assetQuantity: thirdTradeLeftovers)
        let totalStableEquivalentLeftover = secondTradeStableLeftovers + leftoversAfterRoundingStableEquivalent + thirdTradeStableEquivalentLeftover
        if totalStableEquivalentLeftover > 0.0 {
            opportunity.autotradeLog.append("\nTotal leftovers: ≈ \(totalStableEquivalentLeftover.string(maxFractionDigits: 6)) USDT")
        }
        
        opportunity.autotradeLog.append("\nUsed Capital: \(usedCapital) | Actual Resulting Amount: \(actualResultingAmount)")
        
        let usedCapitalStableEquivalent = try getApproximatesStableEquivalent(asset: opportunity.firstSurfaceResult.swap0, assetQuantity: usedCapital)
        let actualResultingAmountStableEquivalent = try getApproximatesStableEquivalent(asset: opportunity.firstSurfaceResult.swap0, assetQuantity: actualResultingAmount)
        
        let profit: Double = actualResultingAmountStableEquivalent + totalStableEquivalentLeftover - usedCapitalStableEquivalent - commissions
        opportunity.autotradeLog.append("\nActual Profit: ≈ \(profit.string(maxFractionDigits: 4)) USDT")
        opportunity.autotradeLog.append(" | \((profit / usedCapitalStableEquivalent * 100.0).string(maxFractionDigits: 4))%")

        // NOTE: - handle email sending
        try await EmailAPIService.shared.sendEmail(with: .init(
            personalizations: [.init(to: [.init(email: "ruslanpopesku95@gmail.com")])],
            from: .init(email: "ruslanpopesku95@gmail.com"),
            subject: "Profit: \(profit.string(maxFractionDigits: 4))",
            content: [.init(type: "test type", value: opportunity.tradingDescription)]
        ))
        
        return opportunity
    }
    
}

// MARK: - Helpers

private extension AutoTradingService {
    
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
        let approximatesStableEquivalent = try getApproximatesStableEquivalent(asset: asset, assetQuantity: 1)
        return minimumQuantityStableEquivalent / approximatesStableEquivalent
    }
    
    func getApproximateStableEquivalentDescription(asset: String, quantity: Double) throws -> String {
        let approximatesStableEquivalent = try getApproximatesStableEquivalent(asset: asset, assetQuantity: quantity)
        return " ≈ \(approximatesStableEquivalent.string(maxFractionDigits: 4)) USDT"
    }
    
    
    func getCommissionStableEquivalent(for fills: [BinanceAPIService.Fill]) throws -> Double {
        try fills.map { fill in
            if let commission = Double(fill.commission) {
                let approximatesStableEquivalent = try getApproximatesStableEquivalent(asset: fill.commissionAsset, assetQuantity: commission)
                return approximatesStableEquivalent
            } else {
                return 0
            }
        }.reduce(0, { x, y in x + y })
    }
    
    func getApproximatesStableEquivalent(asset: String, assetQuantity: Double) throws -> Double {
        guard stablesSet.contains(asset) == false else { return assetQuantity }
        
        if let assetToStableSymbol = approximateBookTickers["\(asset)USDT"], let assetToStableApproximatePrice = assetToStableSymbol.sellPrice {
            return assetQuantity * assetToStableApproximatePrice
        } else if let stableToAssetSymbol = approximateBookTickers["USDT\(asset)"], let stableToAssetApproximatePrice = stableToAssetSymbol.buyPrice {
            return assetQuantity / stableToAssetApproximatePrice
        } else {
            throw TradingError.noMinimalPortion(description: "No Approximate Minimal Portion for asset \(asset)")
        }
    }
    
}
