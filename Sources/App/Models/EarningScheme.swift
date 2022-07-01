//
//  EarningScheme.swift
//  
//
//  Created by Ruslan Popesku on 30.06.2022.
//

enum EarningScheme: Int, CaseIterable {
    
    case monobankUSDT_monobankUSDT
    case privatbankUSDT_privabbankUSDT
    case monobankBUSD_monobankUSDT
    case privatbankBUSD_privatbankUSDT
    
    case abankUSDT_monobankUSDT
    case pumbUSDT_monobankUSDT
    
    case wiseUSDT_wiseUSDT
    
    case huobiUSDT_monobankUSDT
    case monobankUSDT_huobiUSDT
    
    case whiteBitUSDT_monobankUSDT
    case monobankUSDT_whiteBitUSDT
    
    case monobankBTC_monobankBTC
    
//    case binancePayUAH_binancePayUAH // + have to add Spot prices handling
    
    var sellOpportunity: Opportunity {
        switch self {
        case .monobankUSDT_monobankUSDT: return .binance(.monobankUSDT)
        case .monobankBUSD_monobankUSDT: return .binance(.monobankBUSD)
        case .privatbankUSDT_privabbankUSDT: return .binance(.privatbankUSDT)
        case .privatbankBUSD_privatbankUSDT: return .binance(.privatbankBUSD)
        case .abankUSDT_monobankUSDT: return .binance(.abankUSDT)
        case .pumbUSDT_monobankUSDT: return .binance(.pumbUSDT)
        case .wiseUSDT_wiseUSDT: return .binance(.wiseUSDT)
//        case .binancePayUAH_binancePayUAH: return .binance(.binancePayUSDT)
        case .huobiUSDT_monobankUSDT: return .huobi(.usdtSpot)
        case .monobankUSDT_huobiUSDT: return .binance(.monobankUSDT)
        case .whiteBitUSDT_monobankUSDT: return .whiteBit(.usdtSpot)
        case .monobankUSDT_whiteBitUSDT: return .binance(.monobankUSDT)
        case .monobankBTC_monobankBTC: return .binance(.monobankBTC)
        }
    }
    
    var buyOpportunity: Opportunity {
        switch self {
        case .monobankUSDT_monobankUSDT, .monobankBUSD_monobankUSDT: return Opportunity.binance(.monobankUSDT)
        case .privatbankUSDT_privabbankUSDT, .privatbankBUSD_privatbankUSDT: return Opportunity.binance(.privatbankUSDT)
        case .abankUSDT_monobankUSDT, .pumbUSDT_monobankUSDT: return Opportunity.binance(.monobankUSDT)
        case .wiseUSDT_wiseUSDT: return Opportunity.binance(.wiseUSDT)
//        case .binancePayUAH_binancePayUAH: return Opportunity.binance(.binancePayUSDT)
            
        case .huobiUSDT_monobankUSDT: return .binance(.monobankUSDT)
        case .monobankUSDT_huobiUSDT: return .huobi(.usdtSpot)
            
        case .whiteBitUSDT_monobankUSDT: return .binance(.monobankUSDT)
        case .monobankUSDT_whiteBitUSDT: return .whiteBit(.usdtSpot)
            
        case .monobankBTC_monobankBTC: return .binance(.monobankBTC)
        }
    }
    
    var shortDescription: String {
        let basicDescription = "\(sellOpportunity.cryptoDescription)(\(sellOpportunity.paymentMethodDescription))-\(buyOpportunity.cryptoDescription)(\(buyOpportunity.paymentMethodDescription))"
        var spacedMessage = basicDescription
        switch self {
        case .monobankUSDT_monobankUSDT, .monobankBUSD_monobankUSDT, .privatbankUSDT_privabbankUSDT, .privatbankBUSD_privatbankUSDT: break
        case .abankUSDT_monobankUSDT: spacedMessage.append("")
        case .pumbUSDT_monobankUSDT: spacedMessage.append("")
        case .wiseUSDT_wiseUSDT: spacedMessage.append("    ")
//        case .binancePayUAH_binancePayUAH: spacedMessage.append("")
        case .huobiUSDT_monobankUSDT: spacedMessage.append("")
        case .monobankUSDT_huobiUSDT: spacedMessage.append(" ")
        case .whiteBitUSDT_monobankUSDT: spacedMessage.append("  ")
        case .monobankUSDT_whiteBitUSDT: spacedMessage.append("  ")
        case .monobankBTC_monobankBTC: spacedMessage.append("    ")
        }
        return spacedMessage
    }
    
    // In
    var profitableSpread: Double {
        switch self {
        case .monobankUSDT_monobankUSDT, .privatbankUSDT_privabbankUSDT: return 0.3
        case .monobankBUSD_monobankUSDT, .privatbankBUSD_privatbankUSDT: return 0.4
        case .abankUSDT_monobankUSDT, .pumbUSDT_monobankUSDT: return 0.35
        case .wiseUSDT_wiseUSDT: return 0.6
//        case .binancePayUAH_binancePayUAH: return 0.6
        case .huobiUSDT_monobankUSDT: return 0.5
        case .monobankUSDT_huobiUSDT: return 0.5
        case .whiteBitUSDT_monobankUSDT: return 0.5
        case .monobankUSDT_whiteBitUSDT: return 0.5
        case .monobankBTC_monobankBTC: return 10000
        }
    }
    
    func getSpreads(for pricesInfo: PricesInfo) -> (dirtySpread: Double, cleanSpread: Double) {
        let dirtySpread = pricesInfo.possibleSellPrice - pricesInfo.possibleBuyPrice
        let buyCommissionAmount = pricesInfo.possibleBuyPrice * self.buyOpportunity.extraCommission / 100.0
        let sellComissionAmount = pricesInfo.possibleSellPrice * self.sellOpportunity.extraCommission / 100.0
        let cleanSpread = dirtySpread - buyCommissionAmount - sellComissionAmount
        return (dirtySpread, cleanSpread)
    }
    
    func getPrettyDescription(with pricesInfo: PricesInfo) -> String {
        let spreads = getSpreads(for: pricesInfo)
        let cleanSpreadPercentString = (spreads.cleanSpread / pricesInfo.possibleSellPrice * 100).toLocalCurrency()
        
        return ("\(self.shortDescription)|\(pricesInfo.possibleSellPrice.toLocalCurrency())-\(pricesInfo.possibleBuyPrice.toLocalCurrency())|\(spreads.dirtySpread.toLocalCurrency()) -\(spreads.cleanSpread.toLocalCurrency())|\(cleanSpreadPercentString)%\n")
    }
    
}
