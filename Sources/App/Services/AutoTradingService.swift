//
//  AutoTradingService.swift
//  
//
//  Created by Ruslan on 12.10.2022.
//

import Vapor
import telegram_vapor_bot
import Jobs
import CoreFoundation

final class AutoTradingService {
    
    private let stablesSet: Set<String> = Set(arrayLiteral: "BUSD", "USDT", "USDC", "TUSD")
    private let allowedAssetsToTrade: Set<String> = Set(arrayLiteral: "BUSD", "USDT", "USDC", "TUSD", "BTC", "ETH", "BNB")
    private let forbiddenAssetsToTrade: Set<String> = Set(arrayLiteral: "RUB")
    
    private var tradeableSymbolsDict: [String: BinanceAPIService.Symbol] = [:]
    private var approximateBookTickers: [String: BookTicker] = [:]
    
    private let minimumQuantityMultipler: Double = 1.5
    private let minimumQuantityStableEquivalent: Double
    private let maximalDifferencePercent = 0.1
    
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
        triangularOpportunitiesDict: [String: TriangularOpportunity],
        for userInfo: UserInfo,
        completion: @escaping(_ finishedTriangularOpportunity: TriangularOpportunity) -> Void
    ) {
        guard let opportunityToTrade = triangularOpportunitiesDict.first(where: { allowedAssetsToTrade.contains($0.value.firstSurfaceResult.swap0) })?.value,
              forbiddenAssetsToTrade.contains(opportunityToTrade.firstSurfaceResult.swap0) == false,
              forbiddenAssetsToTrade.contains(opportunityToTrade.firstSurfaceResult.swap1) == false,
              forbiddenAssetsToTrade.contains(opportunityToTrade.firstSurfaceResult.swap2) == false else {
            return
        }
        
        switch opportunityToTrade.autotradeCicle {
        case .pending:
            guard let lastSurfaceResult = opportunityToTrade.surfaceResults.last else { return }
            
            let depthStartTime = CFAbsoluteTimeGetCurrent()
            getDepth(for: lastSurfaceResult) { [weak self] result in
                guard let self = self else { return }
                
                let depthCheckDuration = String(format: "%.4f", CFAbsoluteTimeGetCurrent() - depthStartTime)
                opportunityToTrade.autotradeLog.append("\nDepth Check time: \(depthCheckDuration)s")
                
                switch result {
                case .success(let depth):
                    let trade1AveragePrice = depth.pairADepth.getAveragePrice(for: lastSurfaceResult.directionTrade1)
                    let trade1PriceDifferencePercent = (trade1AveragePrice - lastSurfaceResult.pairAExpectedPrice) / lastSurfaceResult.pairAExpectedPrice * 100.0
                    guard abs(trade1PriceDifferencePercent) < self.maximalDifferencePercent else {
                        opportunityToTrade.autotradeLog.append("Trade 1 price difference: \(trade1PriceDifferencePercent.string(maxFractionDigits: 4))%\n")
                        completion(opportunityToTrade)
                        return
                    }
                    
                    let trade2AveragePrice = depth.pairBDepth.getAveragePrice(for: lastSurfaceResult.directionTrade2)
                    let trade2PriceDifferencePercent = (trade2AveragePrice - lastSurfaceResult.pairBExpectedPrice) / lastSurfaceResult.pairBExpectedPrice * 100.0
                    guard abs(trade2PriceDifferencePercent) < self.maximalDifferencePercent else {
                        opportunityToTrade.autotradeLog.append("Trade 2 price difference: \(trade2PriceDifferencePercent.string(maxFractionDigits: 4))%\n")
                        completion(opportunityToTrade)
                        return
                    }
                    
                    let trade3AveragePrice = depth.pairCDepth.getAveragePrice(for: lastSurfaceResult.directionTrade3)
                    let trade3PriceDifferencePercent = (trade3AveragePrice - lastSurfaceResult.pairCExpectedPrice) / lastSurfaceResult.pairCExpectedPrice * 100.0
                    guard abs(trade3PriceDifferencePercent) < self.maximalDifferencePercent else {
                        opportunityToTrade.autotradeLog.append("Trade 3 price difference: \(trade3PriceDifferencePercent.string(maxFractionDigits: 4))%\n")
                        completion(opportunityToTrade)
                        return
                    }
                    
                    self.handleFirstTrade(for: opportunityToTrade, completion: completion)
                case .failure(let error):
                    opportunityToTrade.autotradeLog.append(error.localizedDescription)
                    completion(opportunityToTrade)
                    return
                }
            }
        default:
            return
        }
    }
    
    // MARK: - Get depth
    
    private func getDepth(
        for surfaceResult: SurfaceResult,
        completion: @escaping(_ result: Result<TriangularOpportunityDepth, Error>) -> Void
    ) {
        let group = DispatchGroup()
        
        var pairADepth: OrderbookDepth? = nil
        var pairBDepth: OrderbookDepth? = nil
        var pairCDepth: OrderbookDepth? = nil
        
        group.enter()
        BinanceAPIService.shared.getOrderbookDepth(symbol: surfaceResult.contract1, limit: 20) { result in
            switch result {
            case .success(let orderbookDepth):
                pairADepth = orderbookDepth
                group.leave()
                break
            case .failure:
                group.leave()
                break
            }
        }
        group.enter()
        BinanceAPIService.shared.getOrderbookDepth(symbol: surfaceResult.contract2, limit: 20) { result in
            switch result {
            case .success(let orderbookDepth):
                pairBDepth = orderbookDepth
                group.leave()
                break
            case .failure:
                group.leave()
                break
            }
        }
        group.enter()
        BinanceAPIService.shared.getOrderbookDepth(symbol: surfaceResult.contract3, limit: 20) { result in
            switch result {
            case .success(let orderbookDepth):
                pairCDepth = orderbookDepth
                group.leave()
                break
            case .failure:
                group.leave()
                break
            }
        }
        group.notify(queue: .global()) {
            guard let pairADepth = pairADepth, let pairBDepth = pairBDepth, let pairCDepth = pairCDepth else {
                completion(.failure(BinanceAPIService.BinanceError.noData))
                return
            }
            
            let triangularOpportunityDepth = TriangularOpportunityDepth(pairADepth: pairADepth, pairBDepth: pairBDepth, pairCDepth: pairCDepth)
            completion(.success(triangularOpportunityDepth))
        }
    }
    
    // MARK: - First Trade
    
    private func handleFirstTrade(
        for opportunityToTrade: TriangularOpportunity,
        completion: @escaping(_ finishedTriangularOpportunity: TriangularOpportunity) -> Void
    ) {
            guard let firstSymbolDetails = tradeableSymbolsDict[opportunityToTrade.firstSurfaceResult.contract1] else { return }
            
            guard let firstOrderMinNotionalString = firstSymbolDetails.filters.first(where: { $0.filterType == .minNotional })?.minNotional,
                  let firstOrderMinNotional = Double(firstOrderMinNotionalString)
            else {
                opportunityToTrade.autotradeLog.append("\nError: No min notional")
                completion(opportunityToTrade)
                return
            }
            
            let startTime = CFAbsoluteTimeGetCurrent()
            opportunityToTrade.autotradeCicle = .firstTradeStarted
            
            guard let approximateTickerPrice = approximateBookTickers[opportunityToTrade.firstSurfaceResult.contract1]?.buyPrice else { return }
            
            let preferableQuantityForFirstTrade: Double
            switch opportunityToTrade.firstSurfaceResult.directionTrade1 {
            case .baseToQuote:
                let minNotionalEquivalentQuantity = firstOrderMinNotional * minimumQuantityMultipler / approximateTickerPrice
                if let minStableEquivalentQuantity = getApproximateMinimalPortion(for: opportunityToTrade.firstSurfaceResult.swap0) {
                    preferableQuantityForFirstTrade = max(minNotionalEquivalentQuantity, minStableEquivalentQuantity)
                } else {
                    preferableQuantityForFirstTrade = minNotionalEquivalentQuantity
                }
            case .quoteToBase:
                let minNotionalEquivalentQuantity = firstOrderMinNotional * minimumQuantityMultipler
                if let minStableEquivalentQuantity = getApproximateMinimalPortion(for: opportunityToTrade.firstSurfaceResult.swap0) {
                    preferableQuantityForFirstTrade = max(minNotionalEquivalentQuantity, minStableEquivalentQuantity)
                } else {
                    preferableQuantityForFirstTrade = minNotionalEquivalentQuantity
                }
            case .unknown:
                opportunityToTrade.autotradeLog.append("Unknown side")
                completion(opportunityToTrade)
                return
            }
            
            guard let lotSizeMinQtyString = firstSymbolDetails.filters.first(where: { $0.filterType == .lotSize })?.minQty,
                  let lotSizeMinQty = Double(lotSizeMinQtyString) else {
                opportunityToTrade.autotradeLog.append("No Lot_Size for \(opportunityToTrade.firstSurfaceResult.contract2)")
                completion(opportunityToTrade)
                return
            }

            let leftoversAfterRounding = preferableQuantityForFirstTrade.truncatingRemainder(dividingBy: lotSizeMinQty)
            let quantityToExequte = (preferableQuantityForFirstTrade - leftoversAfterRounding).roundToDecimal(8)
            
            guard quantityToExequte > 0 else {
                opportunityToTrade.autotradeLog.append("Quantity to Qxecute is 0 - have to have bigger amount")
                return
            }
            
            BinanceAPIService.shared.newOrder(
                symbol: opportunityToTrade.firstSurfaceResult.contract1,
                side: opportunityToTrade.firstSurfaceResult.directionTrade1,
                type: .market,
                quantity: quantityToExequte,
                quoteOrderQty: quantityToExequte,
                newOrderRespType: .full,
                success: { [weak self] firstOrderResponse in
                    guard let self = self, let firstOrderResponse = firstOrderResponse else {
                        opportunityToTrade.autotradeLog.append("\n\nStep 1: No Response")
                        completion(opportunityToTrade)
                        return
                    }
                    
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
                    
                    self.handleSecondTrade(for: opportunityToTrade,
                                           usedCapital: usedCapital,
                                           firstOrderComission: commission,
                                           preferableQuantityToExecute: preferableQuantityForSecondTrade,
                                           startTime: startTime,
                                           completion: completion)
                }, failure: { error in
                    var errorDescription: String
                    if let binanceError = error as? BinanceAPIService.BinanceError {
                        errorDescription = binanceError.description
                    } else {
                        errorDescription = error.localizedDescription
                    }
                    errorDescription.append("\nQuantity: \(quantityToExequte.string(maxFractionDigits: 8)), lotSizeMinQty: \(lotSizeMinQty), minNotional: \(firstOrderMinNotional)")
                    opportunityToTrade.autotradeCicle = .firstTradeError(description: errorDescription)
                    opportunityToTrade.autotradeLog.append("\n\n Step 1:\(errorDescription)")
                    completion(opportunityToTrade)
                }
            )
    }
    // MARK: - Second Trade
    
    private func handleSecondTrade(
        for opportunityToTrade: TriangularOpportunity,
        usedCapital: Double,
        firstOrderComission: Double,
        preferableQuantityToExecute: Double,
        startTime: CFAbsoluteTime,
        completion: @escaping(_ finishedTriangularOpportunity: TriangularOpportunity) -> Void
    ) {
        opportunityToTrade.autotradeCicle = .secondTradeStarted
        
        guard let secondSymbolDetails = tradeableSymbolsDict[opportunityToTrade.firstSurfaceResult.contract2],
              let lotSizeMinQtyString = secondSymbolDetails.filters.first(where: { $0.filterType == .lotSize })?.minQty,
              let lotSizeMinQty = Double(lotSizeMinQtyString),
              let minNotionalString = secondSymbolDetails.filters.first(where: { $0.filterType == .minNotional })?.minNotional,
              let tickSizeString = secondSymbolDetails.filters.first(where: { $0.filterType == .priceFilter })?.tickSize,
              let tickSize = Double(tickSizeString)
        else {
            opportunityToTrade.autotradeLog.append("No Lot_Size for \(opportunityToTrade.firstSurfaceResult.contract2)")
            completion(opportunityToTrade)
            return
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
        BinanceAPIService.shared.newOrder(
            symbol: opportunityToTrade.firstSurfaceResult.contract2,
            side: opportunityToTrade.firstSurfaceResult.directionTrade2,
            type: .market,
            quantity: quantityToExequte,
            quoteOrderQty: quantityToExequte,
            newOrderRespType: .full,
            success: { [weak self] secondOrderResponse in
                guard let self = self, let secondOrderResponse = secondOrderResponse else {
                    opportunityToTrade.autotradeLog.append("\n\nStep 2: No Response")
                    completion(opportunityToTrade)
                    return
                }
                
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
                
                self.handleThirdTrade(for: opportunityToTrade,
                                      usedCapital: usedCapital,
                                      commissions: firstOrderComission + secondOrderComission,
                                      preferableQuantityToExecute: preferableQuantityFotThirdTrade,
                                      startTime: startTime,
                                      secondTradeStableLeftovers: leftoversAfterRoundingStableEquivalent + approximatesStableEquivalentLeftover,
                                      completion: completion)
            }, failure: { error in
                var errorDescription: String
                if let binanceError = error as? BinanceAPIService.BinanceError {
                    errorDescription = binanceError.description
                } else {
                    errorDescription = error.localizedDescription
                }
                errorDescription.append("\nQuantity: \(quantityToExequte.string(maxFractionDigits: 8)), preferableQuantityToExecute: \(preferableQuantityToExecute), lotSizeMinQty: \(lotSizeMinQty), minNotional: \(minNotionalString)")
                opportunityToTrade.autotradeCicle = .secondTradeError(description: errorDescription)
                opportunityToTrade.autotradeLog.append("\n\n Step 2:\(errorDescription)")
                completion(opportunityToTrade)
            }
        )
    }
    
    // MARK: - Third Trade
    
    private func handleThirdTrade(
        for opportunityToTrade: TriangularOpportunity,
        usedCapital: Double,
        commissions: Double,
        preferableQuantityToExecute: Double,
        startTime: CFAbsoluteTime,
        secondTradeStableLeftovers: Double, // USDT
        completion: @escaping(_ finishedTriangularOpportunity: TriangularOpportunity) -> Void
    ) {
        opportunityToTrade.autotradeCicle = .thirdTradeStarted
        
        guard let thirdSymbolDetails = tradeableSymbolsDict[opportunityToTrade.firstSurfaceResult.contract3],
              let lotSizeMinQtyString = thirdSymbolDetails.filters.first(where: { $0.filterType == .lotSize })?.minQty,
              let lotSizeMinQty = Double(lotSizeMinQtyString),
              let minNotionalString = thirdSymbolDetails.filters.first(where: { $0.filterType == .minNotional })?.minNotional,
              let tickSizeString = thirdSymbolDetails.filters.first(where: { $0.filterType == .priceFilter })?.tickSize,
              let tickSize = Double(tickSizeString)
        else {
            opportunityToTrade.autotradeLog.append("No Lot_Size for \(opportunityToTrade.firstSurfaceResult.contract3)")
            completion(opportunityToTrade)
            return
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
        BinanceAPIService.shared.newOrder(
            symbol: opportunityToTrade.firstSurfaceResult.contract3,
            side: opportunityToTrade.firstSurfaceResult.directionTrade3,
            type: .market,
            quantity: quantityToExequte,
            quoteOrderQty: quantityToExequte,
            newOrderRespType: .full,
            success: { [weak self] thirdOrderResponse in
                guard let self = self, let thirdOrderResponse = thirdOrderResponse else {
                    opportunityToTrade.autotradeLog.append("\n\nStep 3: No Response")
                    completion(opportunityToTrade)
                    return
                }
                
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
                completion(opportunityToTrade)
            }, failure: { error in
                var errorDescription: String
                if let binanceError = error as? BinanceAPIService.BinanceError {
                    errorDescription = binanceError.description
                } else {
                    errorDescription = error.localizedDescription
                }
                errorDescription.append("\nQuantity: \(quantityToExequte.string(maxFractionDigits: 8)), preferableQuantityToExecute \(preferableQuantityToExecute), lotSizeMinQty: \(lotSizeMinQty), minNotional: \(minNotionalString)")
                opportunityToTrade.autotradeCicle = .thirdTradeError(description: errorDescription)
                opportunityToTrade.autotradeLog.append("\n\nStep 3: \(errorDescription)")
                completion(opportunityToTrade)
            }
        )
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
