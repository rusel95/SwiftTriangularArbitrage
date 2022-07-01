//
//  Opportunity.swift
//  
//
//  Created by Ruslan Popesku on 30.06.2022.
//

enum Opportunity: Equatable {
    
    enum Binance {
        case monobankUSDT
        case monobankBUSD
        case privatbankUSDT
        case privatbankBUSD
        case abankUSDT
        case pumbUSDT
        case wiseUSDT
        case binancePayUSDT
        
        case monobankBTC
        case monobankBNB
        
        var crypto: Crypto {
            switch self {
            case .monobankUSDT, .privatbankUSDT, .abankUSDT, .pumbUSDT, .wiseUSDT, .binancePayUSDT: return .binance(.usdt)
            case .monobankBUSD, .privatbankBUSD: return .binance(.busd)
            case .monobankBTC: return .binance(.btc)
            case .monobankBNB: return .binance(.bnb)
            }
        }
        
        var paymentMethod: PaymentMethod {
            switch self {
            case .monobankUSDT, .monobankBUSD: return .binance(.monobank)
            case .privatbankUSDT, .privatbankBUSD: return .binance(.privatbank)
            case .abankUSDT: return .binance(.abank)
            case .pumbUSDT: return .binance(.pumb)
            case .wiseUSDT: return .binance(.wise)
            case .binancePayUSDT: return .binance(.binancePayUAH)
            case .monobankBTC: return .binance(.monobank)
            case .monobankBNB: return .binance(.monobank)
            }
        }
    
        var numberOfAdvsToConsider: UInt8 {
            switch self {
            case .monobankUSDT, .privatbankUSDT: return 10
            case .monobankBUSD, .privatbankBUSD: return 2
            case .abankUSDT, .pumbUSDT, .wiseUSDT, .binancePayUSDT: return 2
            case .monobankBTC, .monobankBNB: return 1
            }
        }
        
        // in percents
        var extraCommission: Double {
            switch self {
            case .monobankUSDT, .privatbankUSDT, .abankUSDT, .pumbUSDT, .wiseUSDT: return 0.1
            case .monobankBUSD, .privatbankBUSD: return 0.2
            case .binancePayUSDT: return 0.0
            case .monobankBTC, .monobankBNB: return 0.1
            }
        }
    
    }
    
    enum WhiteBit {
        
        case usdtSpot
        
        var paymentMethod: PaymentMethod {
            switch self {
            case .usdtSpot: return .whiteBit(.usdtuahSpot)
            }
        }
        
        var crypto: Crypto {
            switch self {
            case .usdtSpot: return .whiteBit(.usdt)
            }
        }
        
        // in percents
        var extraCommission: Double {
            switch self {
            case .usdtSpot: return 0.5
            }
        }
        
    }
    
    enum Huobi {
        
        case usdtSpot
        
        var paymentMethod: PaymentMethod {
            switch self {
            case .usdtSpot: return .huobi(.usdtuahSpot)
            }
        }
        
        var crypto: Crypto {
            switch self {
            case .usdtSpot: return .huobi(.usdt)
            }
        }
        
        // in percents
        var extraCommission: Double {
            switch self {
            case .usdtSpot: return 1
            }
        }
    }
    
    case binance(Binance)
    case huobi(Huobi)
    case whiteBit(WhiteBit)
    
    var paymentMethodDescription: String {
        switch self {
        case .binance(let opportunity):
            return opportunity.paymentMethod.description
        case .whiteBit(let opportunity):
            return opportunity.paymentMethod.description
        case .huobi(let opportunity):
            return opportunity.paymentMethod.description
        }
    }
    
    var cryptoDescription: String {
        switch self {
        case .binance(let opportunity):
            return opportunity.crypto.apiDescription
        case .whiteBit(let opportunity):
            return opportunity.crypto.apiDescription
        case .huobi(let opportunity):
            return opportunity.crypto.apiDescription
        }
    }
    
    // in percents
    var extraCommission: Double {
        switch self {
        case .binance(let opportunity):
            return opportunity.extraCommission
        case .whiteBit(let opportunity):
            return opportunity.extraCommission
        case .huobi(let opportunity):
            return opportunity.extraCommission
        }
    }
    
}
