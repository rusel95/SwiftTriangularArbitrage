//
//  EarningScheme.swift
//  
//
//  Created by Ruslan Popesku on 30.06.2022.
//

enum EarningScheme: CaseIterable {
    
    case monobankUSDT_monobankUSDT
    case privatbankUSDT_privabbankUSDT
    case abankUSDT_monobankUSDT
    case pumbUSDT_monobankUSDT
    case wiseUSDT_wiseUSDT
    case monobankBUSD_monobankUSDT
    case privatbankBUSD_privatbankUSDT
    case binancePayUAH_binancePayUAH // + have to add Spot prices handling
    
    case huobiUSDT_monobankUSDT
    case monobankUSDT_huobiUSDT
    
    var sellOpportunity: Opportunity {
        switch self {
        case .monobankUSDT_monobankUSDT: return Opportunity.binance(.monobankUSDT)
        case .monobankBUSD_monobankUSDT: return Opportunity.binance(.monobankBUSD)
        case .privatbankUSDT_privabbankUSDT: return Opportunity.binance(.privatbankUSDT)
        case .privatbankBUSD_privatbankUSDT: return Opportunity.binance(.privatbankBUSD)
        case .abankUSDT_monobankUSDT: return Opportunity.binance(.abankUSDT)
        case .pumbUSDT_monobankUSDT: return Opportunity.binance(.pumbUSDT)
        case .wiseUSDT_wiseUSDT: return Opportunity.binance(.wiseUSDT)
        case .binancePayUAH_binancePayUAH: return Opportunity.binance(.binancePayUSDT)
        case .huobiUSDT_monobankUSDT: return Opportunity.huobi(.usdtSpot)
        case .monobankUSDT_huobiUSDT: return Opportunity.binance(.monobankUSDT)
        }
    }
    
    var buyOpportunity: Opportunity {
        switch self {
        case .monobankUSDT_monobankUSDT, .monobankBUSD_monobankUSDT: return Opportunity.binance(.monobankUSDT)
        case .privatbankUSDT_privabbankUSDT, .privatbankBUSD_privatbankUSDT: return Opportunity.binance(.privatbankUSDT)
        case .abankUSDT_monobankUSDT, .pumbUSDT_monobankUSDT: return Opportunity.binance(.monobankUSDT)
        case .wiseUSDT_wiseUSDT: return Opportunity.binance(.wiseUSDT)
        case .binancePayUAH_binancePayUAH: return Opportunity.binance(.binancePayUSDT)
        case .huobiUSDT_monobankUSDT: return .binance(.monobankUSDT)
        case .monobankUSDT_huobiUSDT: return .huobi(.usdtSpot)
        }
    }
    
    var description: String {
        let basicDescription = "\(sellOpportunity.cryptoDescription)(\(sellOpportunity.paymentMethodDescription)) / \(buyOpportunity.cryptoDescription) (\(buyOpportunity.paymentMethodDescription)) "
        var spacedMessage = basicDescription
        switch self {
        case .monobankUSDT_monobankUSDT, .monobankBUSD_monobankUSDT, .privatbankUSDT_privabbankUSDT, .privatbankBUSD_privatbankUSDT: break
        case .abankUSDT_monobankUSDT: spacedMessage.append("        ")
        case .pumbUSDT_monobankUSDT: spacedMessage.append("")
        case .wiseUSDT_wiseUSDT: spacedMessage.append("                    ")
        case .binancePayUAH_binancePayUAH: spacedMessage.append("")
        case .huobiUSDT_monobankUSDT: spacedMessage.append("")
        case .monobankUSDT_huobiUSDT: spacedMessage.append(" ")
        }
        return spacedMessage
    }
    
    var profitableSpread: Double {
        switch self {
        case .monobankUSDT_monobankUSDT, .privatbankUSDT_privabbankUSDT: return 0.1
        case .monobankBUSD_monobankUSDT, .privatbankBUSD_privatbankUSDT: return 0.45
        case .abankUSDT_monobankUSDT, .pumbUSDT_monobankUSDT: return 0.35
        case .wiseUSDT_wiseUSDT: return 0.4
        case .binancePayUAH_binancePayUAH: return 0.6
        case .huobiUSDT_monobankUSDT: return 0.1
        case .monobankUSDT_huobiUSDT: return 0.1
        }
    }
    
    func getPrettyDescription(with pricesInfo: PricesInfo) -> String {
        let dirtySpread = pricesInfo.possibleSellPrice - pricesInfo.possibleBuyPrice
        let cleanSpread = dirtySpread - pricesInfo.possibleSellPrice * 0.001 * 2 // 0.1 % Binance Commission
        let cleanSpreadPercentString = (cleanSpread / pricesInfo.possibleSellPrice * 100).toLocalCurrency()
        
        return ("\(self.description) | \(pricesInfo.possibleSellPrice.toLocalCurrency()) - \(pricesInfo.possibleBuyPrice.toLocalCurrency()) | \(dirtySpread.toLocalCurrency()) - \(cleanSpread.toLocalCurrency()) | \(cleanSpreadPercentString)%\n")
    }
    
}
