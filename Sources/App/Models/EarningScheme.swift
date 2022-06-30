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
        }
    }
    
    var buyOpportunity: Opportunity {
        switch self {
        case .monobankUSDT_monobankUSDT, .monobankBUSD_monobankUSDT: return Opportunity.binance(.monobankUSDT)
        case .privatbankUSDT_privabbankUSDT, .privatbankBUSD_privatbankUSDT: return Opportunity.binance(.privatbankUSDT)
        case .abankUSDT_monobankUSDT, .pumbUSDT_monobankUSDT: return Opportunity.binance(.monobankUSDT)
        case .wiseUSDT_wiseUSDT: return Opportunity.binance(.wiseUSDT)
        case .binancePayUAH_binancePayUAH: return Opportunity.binance(.binancePayUSDT)
        }
    }
    
    var description: String {
        let basicDescription = "\(sellOpportunity.cryptoDescription)(\(sellOpportunity.paymentMethodDescription)) / \(buyOpportunity.cryptoDescription) (\(buyOpportunity.paymentMethodDescription)) "
        var spacedMessage = basicDescription
        switch self {
        case .monobankUSDT_monobankUSDT, .monobankBUSD_monobankUSDT, .privatbankUSDT_privabbankUSDT, .privatbankBUSD_privatbankUSDT: break
        case .abankUSDT_monobankUSDT: spacedMessage.append("        ")
        case .pumbUSDT_monobankUSDT: spacedMessage.append(" ")
        case .wiseUSDT_wiseUSDT: spacedMessage.append("                    ")
            case .binancePayUAH_binancePayUAH: spacedMessage.append("")
        }
        return spacedMessage
    }
    
}
