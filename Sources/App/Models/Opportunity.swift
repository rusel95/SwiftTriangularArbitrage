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
        case wiseBUSD
        case binancePayUSDT
        
        case monobankBTC
        case monobankBNB
        
        var crypto: Crypto.Binance {
            switch self {
            case .monobankUSDT, .privatbankUSDT, .abankUSDT, .pumbUSDT, .wiseUSDT, .binancePayUSDT: return .usdt
            case .monobankBUSD, .privatbankBUSD, .wiseBUSD: return .busd
            case .monobankBTC: return .btc
            case .monobankBNB: return .bnb
            }
        }
        
        var paymentMethod: PaymentMethod {
            switch self {
            case .monobankUSDT, .monobankBUSD: return .binance(.monobank)
            case .privatbankUSDT, .privatbankBUSD: return .binance(.privatbank)
            case .abankUSDT: return .binance(.abank)
            case .pumbUSDT: return .binance(.pumb)
            case .wiseUSDT, .wiseBUSD: return .binance(.wise)
            case .binancePayUSDT: return .binance(.binancePayUAH)
            case .monobankBTC: return .binance(.monobank)
            case .monobankBNB: return .binance(.monobank)
            }
        }
    
        var numberOfAdvsToConsider: Int {
            switch self {
            case .monobankUSDT, .privatbankUSDT: return 10
            case .monobankBUSD, .privatbankBUSD: return 1
            case .abankUSDT, .pumbUSDT, .wiseUSDT, .binancePayUSDT, .monobankBTC, .monobankBNB, .wiseBUSD: return 2
            }
        }
        
        // in percents
        var extraCommission: Double {
            switch self {
            case .monobankUSDT, .privatbankUSDT, .abankUSDT, .pumbUSDT, .wiseUSDT: return 0.1
            case .monobankBUSD, .privatbankBUSD, .wiseBUSD: return 0.2
            case .binancePayUSDT: return 0.0
            case .monobankBTC, .monobankBNB: return 0.1
            }
        }
        
        // minimum adv size (in Asset's currency)
        var minSurplusAmount: Double {
            switch self {
            case .monobankUSDT, .privatbankUSDT: return 200 // ±200 USDT
            case .abankUSDT, .pumbUSDT, .wiseUSDT, .monobankBUSD, .privatbankBUSD, .wiseBUSD: return 100 // ± 100 USDT
            case .binancePayUSDT: return 500 // ± 500 UAH
            case .monobankBTC: return 0.005 // ± 1000 UAH
            case .monobankBNB: return 0.1 // ± 1000 UAH
            }
        }
        
        // (in Fiat's currency - UAH)
        var minSingleTransAmount: Double {
            switch self {
            case .monobankUSDT: return 3000
            case .privatbankUSDT: return 5000
            case .abankUSDT, .pumbUSDT, .wiseUSDT, .monobankBUSD, .privatbankBUSD, .wiseBUSD: return 500
            case .binancePayUSDT, .monobankBTC, .monobankBNB: return 500
            }
        }
        
        // (in Fiat's currency - UAH)
        var maxSingleTransAmount: Double {
            switch self {
            case .monobankUSDT, .privatbankUSDT: return 100000
            case .abankUSDT, .pumbUSDT, .wiseUSDT, .monobankBUSD, .privatbankBUSD, .wiseBUSD: return 30000
            case .binancePayUSDT, .monobankBTC, .monobankBNB: return 15000
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
            case .usdtSpot: return 0.1
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
    
    var description: String {
        "\(self.cryptoDescription)(\(self.paymentMethodDescription))"
    }
    
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
            return opportunity.crypto.rawValue
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
