//
//  Opportunity.swift
//  
//
//  Created by Ruslan Popesku on 30.06.2022.
//

enum Opportunity: Equatable {
    
    // MARK: - BINANCE
    
    enum Binance: Equatable {
        
        enum P2P {
            
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
            
            var crypto: Crypto {
                switch self {
                case .monobankUSDT, .privatbankUSDT, .abankUSDT, .pumbUSDT, .wiseUSDT, .binancePayUSDT: return .usdt
                case .monobankBUSD, .privatbankBUSD, .wiseBUSD: return .busd
                case .monobankBTC: return .btc
                case .monobankBNB: return .bnb
                }
            }
            
            var paymentMethod: PaymentMethod {
                switch self {
                case .monobankUSDT, .monobankBUSD: return .binance(.p2p(.monobank))
                case .privatbankUSDT, .privatbankBUSD: return .binance(.p2p(.privatbank))
                case .abankUSDT: return .binance(.p2p(.abank))
                case .pumbUSDT: return .binance(.p2p(.pumb))
                case .wiseUSDT, .wiseBUSD: return .binance(.p2p(.wise))
                case .binancePayUSDT: return .binance(.p2p(.binancePayUAH))
                case .monobankBTC: return .binance(.p2p(.monobank))
                case .monobankBNB: return .binance(.p2p(.monobank))
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
        
        enum Spot {
            
            case usdtUAH
            
            var crypto: Crypto {
                switch self {
                case .usdtUAH: return .usdt
                }
            }
            
            var paymentMethod: PaymentMethod.Binance.Spot {
                switch self {
                case .usdtUAH: return .usdtUAH
                }
            }
            
            // in percents
            var extraCommission: Double {
                switch self {
                case .usdtUAH: return 0.1
                }
            }
            
        }
        
        case p2p(P2P)
        case spot(Spot)
        
    }
    
    // MARK: - WHITEBIT
    
    enum WhiteBit {
        
        case usdtSpot
        
        var paymentMethod: PaymentMethod {
            switch self {
            case .usdtSpot: return .whiteBit(.usdtuahSpot)
            }
        }
        
        var crypto: Crypto {
            switch self {
            case .usdtSpot: return .usdt
            }
        }
        
        // in percents
        var extraCommission: Double {
            switch self {
            case .usdtSpot: return 0.2
            }
        }
        
    }
    
    // MARK: - HUOBI
    enum Huobi {
        
        case usdtSpot
        
        var paymentMethod: PaymentMethod {
            switch self {
            case .usdtSpot: return .huobi(.usdtuahSpot)
            }
        }
        
        var crypto: Crypto {
            switch self {
            case .usdtSpot: return .usdt
            }
        }
        
        // in percents
        var sellCommission: Double {
            switch self {
            case .usdtSpot: return 1.1
            }
        }
        
        // in percents
        var buyCommission: Double {
            switch self {
            case .usdtSpot: return 1.5
            }
        }
    }
    
    // MARK: - EXMO
    
    enum EXMO {
        
        case usdtUAHSpot
        
        var paymentMethod: PaymentMethod {
            switch self {
            case .usdtUAHSpot: return .exmo(.usdtuahSpot)
            }
        }
        
        var crypto: Crypto {
            switch self {
            case .usdtUAHSpot: return .usdt
            }
        }
        
        // in percents
        var extraCommission: Double {
            switch self {
            case .usdtUAHSpot: return 0.2
            }
        }
    }
    
    // MARK: - Kuna
    
    enum Kuna {
        
        case usdtUAHSpot
        
        var paymentMethod: PaymentMethod {
            switch self {
            case .usdtUAHSpot: return .kuna(.usdtuahSpot)
            }
        }
        
        var crypto: Crypto {
            switch self {
            case .usdtUAHSpot: return .usdt
            }
        }
        
        // in percents
        var extraCommission: Double {
            switch self {
            case .usdtUAHSpot: return 1.6
            }
        }
        
    }
    
    // MARK: - Cases
    
    case binance(Binance)
    case huobi(Huobi)
    case whiteBit(WhiteBit)
    case exmo(EXMO)
    case kuna(Kuna)
    
    // MARK: - PARAMETERS
    
    var description: String {
        "\(self.cryptoDescription)(\(self.paymentMethodDescription))"
    }
    
    var paymentMethodDescription: String {
        switch self {
        case .binance(let binanceOpportunity):
            switch binanceOpportunity {
            case .p2p(let binanceP2POpportunity):
                return binanceP2POpportunity.paymentMethod.description
            case .spot(let binanceSpotOpportunity):
                return binanceSpotOpportunity.paymentMethod.shortDescription
            }
        case .whiteBit(let opportunity):
            return opportunity.paymentMethod.description
        case .huobi(let opportunity):
            return opportunity.paymentMethod.description
        case .exmo(let exmoOpportunity):
            return exmoOpportunity.paymentMethod.description
        case .kuna(let kunaOpportunity):
            return kunaOpportunity.paymentMethod.description
        }
    }
    
    var cryptoDescription: String {
        switch self {
        case .binance(let binanceOpportunity):
            switch binanceOpportunity {
            case .p2p(let binanceP2POpportunity):
                return binanceP2POpportunity.crypto.apiDescription
            case .spot(let binanceSpotOpportunity):
                return binanceSpotOpportunity.crypto.apiDescription
            }
        case .whiteBit(let opportunity):
            return opportunity.crypto.apiDescription
        case .huobi(let opportunity):
            return opportunity.crypto.apiDescription
        case .exmo(let exmoOpportunity):
            return exmoOpportunity.crypto.apiDescription
        case .kuna(let kunaOpportunity):
            return kunaOpportunity.crypto.apiDescription
        }
    }
    
    // in percents, nil means that opportunity can't be used for selling
    var sellCommission: Double? {
        switch self {
        case .binance(let binanceOpportunity):
            switch binanceOpportunity {
            case .p2p(let binanceP2POpportunity):
                return binanceP2POpportunity.extraCommission
            case .spot(let binanceSpotOpportunity):
                return binanceSpotOpportunity.extraCommission
            }
        case .whiteBit(let opportunity):
            return opportunity.extraCommission
        case .huobi(let opportunity):
            return opportunity.sellCommission
        case .exmo(let exmoOpportunity):
            return exmoOpportunity.extraCommission
        case .kuna(let kunaOpportunity):
            return kunaOpportunity.extraCommission
        }
    }
    
    // in percents, nil means that opportunity can't be used for buying
    var buyCommission: Double? {
        switch self {
        case .binance(let binanceOpportunity):
            switch binanceOpportunity {
            case .p2p(let binanceP2POpportunity):
                return binanceP2POpportunity.extraCommission
            case .spot(let binanceSpotOpportunity):
                return binanceSpotOpportunity.extraCommission
            }
        case .whiteBit(let opportunity):
            return opportunity.extraCommission
        case .huobi(let opportunity):
            return opportunity.buyCommission
        case .exmo(let exmoOpportunity):
            return exmoOpportunity.extraCommission
        case .kuna(let kunaOpportunity):
            return kunaOpportunity.extraCommission
        }
    }
    
}
