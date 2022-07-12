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
    case wiseBUSD_wiseUSDT
    case binancePayUAH_binancePayUAH // + have to add Spot prices handling
    
    case huobiUSDT_monobankUSDT
    case monobankUSDT_huobiUSDT
    
    case whiteBitUSDT_monobankUSDT
    case monobankUSDT_whiteBitUSDT
    
    case monobankBTC_monobankBTC
    case monobankBNB_monobankBNB
    
    var sellOpportunity: Opportunity {
        switch self {
        case .monobankUSDT_monobankUSDT: return .binance(.p2p(.monobankUSDT))
        case .monobankBUSD_monobankUSDT: return .binance(.p2p(.monobankBUSD))
        case .privatbankUSDT_privabbankUSDT: return .binance(.p2p(.privatbankUSDT))
        case .privatbankBUSD_privatbankUSDT: return .binance(.p2p(.privatbankBUSD))
        case .abankUSDT_monobankUSDT: return .binance(.p2p(.abankUSDT))
        case .pumbUSDT_monobankUSDT: return .binance(.p2p(.pumbUSDT))
        case .wiseUSDT_wiseUSDT: return .binance(.p2p(.wiseUSDT))
        case .wiseBUSD_wiseUSDT: return .binance(.p2p(.wiseBUSD))
        case .binancePayUAH_binancePayUAH: return .binance(.p2p(.binancePayUSDT))
        case .huobiUSDT_monobankUSDT: return .huobi(.usdtSpot)
        case .monobankUSDT_huobiUSDT: return .binance(.p2p(.monobankUSDT))
        case .whiteBitUSDT_monobankUSDT: return .whiteBit(.usdtSpot)
        case .monobankUSDT_whiteBitUSDT: return .binance(.p2p(.monobankUSDT))
        case .monobankBTC_monobankBTC: return .binance(.p2p(.monobankBTC))
        case .monobankBNB_monobankBNB: return .binance(.p2p(.monobankBNB))
        }
    }
    
    var buyOpportunity: Opportunity {
        switch self {
        case .monobankUSDT_monobankUSDT, .monobankBUSD_monobankUSDT: return .binance(.p2p(.monobankUSDT))
        case .privatbankUSDT_privabbankUSDT, .privatbankBUSD_privatbankUSDT: return .binance(.p2p(.privatbankUSDT))
        case .abankUSDT_monobankUSDT, .pumbUSDT_monobankUSDT: return .binance(.p2p(.monobankUSDT))
        case .wiseUSDT_wiseUSDT, .wiseBUSD_wiseUSDT: return .binance(.p2p(.wiseUSDT))
        case .binancePayUAH_binancePayUAH: return .binance(.p2p(.binancePayUSDT))
            
        case .huobiUSDT_monobankUSDT: return .binance(.p2p(.monobankUSDT))
        case .monobankUSDT_huobiUSDT: return .huobi(.usdtSpot)
            
        case .whiteBitUSDT_monobankUSDT: return .binance(.p2p(.monobankUSDT))
        case .monobankUSDT_whiteBitUSDT: return .whiteBit(.usdtSpot)
            
        case .monobankBTC_monobankBTC: return .binance(.p2p(.monobankBTC))
        case .monobankBNB_monobankBNB: return .binance(.p2p(.monobankBNB))
        }
    }
    
    var shortDescription: String {
        var spacedMessage = "\(sellOpportunity.description)-\(buyOpportunity.description))"
        switch self {
        case .monobankUSDT_monobankUSDT, .monobankBUSD_monobankUSDT, .privatbankUSDT_privabbankUSDT, .privatbankBUSD_privatbankUSDT: break
        case .abankUSDT_monobankUSDT: spacedMessage.append("")
        case .pumbUSDT_monobankUSDT: spacedMessage.append("")
        case .wiseUSDT_wiseUSDT, .wiseBUSD_wiseUSDT: spacedMessage.append("    ")
        case .binancePayUAH_binancePayUAH: spacedMessage.append("        ")
        case .huobiUSDT_monobankUSDT: spacedMessage.append("")
        case .monobankUSDT_huobiUSDT: spacedMessage.append("")
        case .whiteBitUSDT_monobankUSDT: spacedMessage.append("")
        case .monobankUSDT_whiteBitUSDT: spacedMessage.append("")
        case .monobankBTC_monobankBTC: spacedMessage.append("       ")
        case .monobankBNB_monobankBNB: spacedMessage.append("       ")
        }
        return spacedMessage
    }
    
    // In UAH (should be shown in percents)
    var profitableSpread: Double {
        switch self {
        case .monobankUSDT_monobankUSDT, .privatbankUSDT_privabbankUSDT: return 0.3
        case .monobankBUSD_monobankUSDT, .privatbankBUSD_privatbankUSDT: return 0.4
        case .abankUSDT_monobankUSDT, .pumbUSDT_monobankUSDT: return 0.35
        case .wiseUSDT_wiseUSDT: return 0.5
        case .binancePayUAH_binancePayUAH, .wiseBUSD_wiseUSDT: return 0.6
        case .huobiUSDT_monobankUSDT: return 0.5
        case .monobankUSDT_huobiUSDT: return 0.5
        case .whiteBitUSDT_monobankUSDT: return 0.5
        case .monobankUSDT_whiteBitUSDT: return 0.5
        case .monobankBTC_monobankBTC: return 20000
        case .monobankBNB_monobankBNB: return 400
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
        
        return ("\(self.shortDescription)|\(pricesInfo.possibleSellPrice.toLocalCurrency())-\(pricesInfo.possibleBuyPrice.toLocalCurrency())|\(spreads.dirtySpread.toLocalCurrency())-\(spreads.cleanSpread.toLocalCurrency())|\(cleanSpreadPercentString)%\n")
    }
    
}
