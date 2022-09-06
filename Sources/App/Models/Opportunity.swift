//
//  Opportunity.swift
//  
//
//  Created by Ruslan Popesku on 30.06.2022.
//

enum Opportunity: Equatable {
    
    // MARK: - BINANCE
    
    enum Binance: Equatable {
        
        // Should be MAKER/NON-maker opportunity also
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
            
            var mainAsset: Currency {
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
            
            case usdt_uah
            case btc_uah
            
            var mainAsset: Currency {
                switch self {
                case .usdt_uah: return .usdt
                case .btc_uah: return .btc
                }
            }
            
            var paymentMethod: PaymentMethod.Binance.Spot {
                switch self {
                case .usdt_uah: return .usdtuah
                case .btc_uah: return .btcuah
                }
            }
            
            // in percents
            var sellCommission: Double? {
                switch self {
                case .usdt_uah: return 1.1  // 1% SettlePay + 0.1% SPOT comission
                case .btc_uah:  return 1.1  // 1% SettlePay + 0.1% SPOT comission
                }
            }
            
            // in percents
            var buyCommission: Double {
                switch self {
                case .usdt_uah: return 1.6  // 1.5% SettlePay Deposit Comission + 0.1 % SPOT comission
                case .btc_uah:  return 1.6  // 1.5% SettlePay Deposit Comission + 0.1 % SPOT comission
                }
            }
            
        }
        
        case p2p(P2P)
        case spot(Spot)
        
    }
    
    // MARK: - WHITEBIT
    
    enum WhiteBit {
        
        case usdt_uah
        case btc_uah
        
        var paymentMethod: PaymentMethod {
            switch self {
            case .usdt_uah: return .whiteBit(.usdt_uah)
            case .btc_uah: return .whiteBit(.btc_uah)
            }
        }
        
        var mainAsset: Currency {
            switch self {
            case .usdt_uah: return .usdt
            case .btc_uah: return .btc
            }
        }
        
        // in percents
        var sellCommission: Double {
            switch self {
            case .usdt_uah: return 0.2  // 1 USDT Deposit + 0.1 % SPOT comission
            case .btc_uah:  return 0.2  // BEP20 is cheap + 0.1 % SPOT comission
            }
        }
        
        // in percents
        var buyCommission: Double {
            switch self {
            case .usdt_uah: return 0.2  // 1 USDT Withdrawal + 0.1 % SPOT comission
            case .btc_uah:  return 1.1  // 0.0004 BTC ± 10$ + 0.1 % SPOT comission
            }
        }
        
    }
    
    // MARK: - Huobi
    
    enum Huobi {
        
        case usdt_uah
        case btc_uah
        
        var paymentMethod: PaymentMethod {
            switch self {
            case .usdt_uah: return .huobi(.usdt_uah)
            case .btc_uah:  return .huobi(.btc_uah)
            }
        }
        
        var mainAsset: Currency {
            switch self {
            case .usdt_uah: return .usdt
            case .btc_uah:  return .btc
            }
        }
        
        // in percents
        var sellCommission: Double? {
            return nil // currently available only AdvCach
//            switch self {
//            case .usdt_uah: return 1.3  // 1 USDT Deposit + 1% UAH Widthdrawal + 0.2 % SPOT comission
//            case .btc_uah:  return 1.25 // Cheap BTC Deposit + 1% UAH Widthdrawal + 0.2 % SPOT comission
//            }
        }
        
        // in percents
        var buyCommission: Double {
            switch self {
            case .usdt_uah: return 1.8  // 1.5 % UAH Deposit + 1 USDT Widthdrawal + 0.2 % SPOT comission
            case .btc_uah: return 1.75  // 1.5 % UAH Deposit + cheap widthdrawal + 0.2 % SPOT comission
            }
        }
    }
    
    // MARK: - EXMO
    
    enum EXMO {
        
        case usdt_uah
        case btc_uah
        
        var paymentMethod: PaymentMethod {
            switch self {
            case .usdt_uah: return .exmo(.usdt_uah)
            case .btc_uah: return .exmo(.btc_uah)
            }
        }
        
        var mainAsset: Currency {
            switch self {
            case .usdt_uah: return .usdt
            case .btc_uah:  return .btc
            }
        }
        
        // in percents
        var sellCommission: Double {
            switch self {
            case .usdt_uah: return 1.4  // 1 USDT Deposit + 1% UAH Widthdrawal + 0.3 % SPOT comission
            case .btc_uah:  return 1.35 // Cheap btc Deposit + 1% UAH Widthdrawal + 0.3 % SPOT comission
            }
        }
        
        // in percents
        var buyCommission: Double? {
            switch self {
            case .usdt_uah: return 0.9   // 0.5% UAH Deposit + 1 USDT Widthdrawal + 0.3 % SPOT comission
            case .btc_uah:  return 0.85  // 0.5% UAH Deposit + Cheap BTC Widthdrawal + 0.3 % SPOT comission
            }
        }
    }
    
    // MARK: - Kuna
    
    enum Kuna {
        
        case usdt_uah
        case btc_uah
        
        var paymentMethod: PaymentMethod {
            switch self {
            case .usdt_uah: return .kuna(.usdt_uah)
            case .btc_uah: return .kuna(.btc_uah)
            }
        }
        
        var mainAsset: Currency {
            switch self {
            case .usdt_uah: return .usdt
            case .btc_uah:     return .btc
            }
        }
        
        // in percents
        var commission: Double {
            switch self {
            case .usdt_uah: return 1.95 // 1.55% UAH Deposit/Widthdrawal + 1 USDT Deposit/Widthdrawal + 0.25 % SPOT comission
            case .btc_uah:  return 1.85  // 1.55% UAH Deposit/Widthdrawal + Cheap BTC Deposit/Widthdrawal + 0.25 % SPOT comission
            }
        }
        
    }
    
    // MARK: - Coinsbit
    
    enum Coinsbit {
        
        case usdt_uah
        case btc_uah
        
        var paymentMethod: PaymentMethod {
            switch self {
            case .usdt_uah: return .coinsbit(.usdt_uah)
            case .btc_uah:  return .coinsbit(.btc_uah)
            }
        }
        
        var mainAsset: Currency {
            switch self {
            case .usdt_uah: return .usdt
            case .btc_uah:  return .btc
            }
        }
        
        // in percents
        var commissions: Double {
            switch self {
            case .usdt_uah: return 1.3  // 1% UAH Deposit/Widthdrawal + 1 USDT Deposit/Widthdrawal + 0.2 % SPOT comission
            case .btc_uah:  return 1.25 // 1% UAH Deposit/Widthdrawal + Cheap BTC Deposit/Widthdrawal + 0.2 % SPOT comission
            }
        }
        
    }
    
    // MARK: - Betconix
    
    enum Betconix {
        
        case usdt_uah
        case btc_uah
        
        var paymentMethod: PaymentMethod {
            switch self {
            case .usdt_uah: return .betconix(.usdt_uah)
            case .btc_uah:  return .betconix(.btc_uah)
            }
        }
        
        var mainAsset: Currency {
            switch self {
            case .usdt_uah: return .usdt
            case .btc_uah:  return .btc
            }
        }
        
        // in percents
        var sellCommission: Double {
            switch self {
            case .usdt_uah: return 0.35 // 1 USDT for Deposit + 0.25% UAH Withdrawal
            case .btc_uah:  return 0.3  // Cheap BTC Deposit + 0.25% UAH Withdrawal
            }
        }
        
        // in percents
        var buyCommission: Double {
            switch self {
            case .usdt_uah: return 1.8  // 1.3% UAH Deposit + 5 USDT Withdrawal
            case .btc_uah:  return 1.35 // 1.3% UAH Deposit + Cheap BTC Withdrawal
            }
        }
        
    }
    
    // MARK: - Coinsbit
    
    enum QMall {
        
        case usdt_uah
        case btc_uah
        
        var paymentMethod: PaymentMethod {
            switch self {
            case .usdt_uah: return .qmall(.usdt_uah)
            case .btc_uah:  return .qmall(.btc_uah)
            }
        }
        
        var mainAsset: Currency {
            switch self {
            case .usdt_uah: return .usdt
            case .btc_uah:  return .btc
            }
        }
        
        // in percents
        var commissions: Double {
            switch self {
            case .usdt_uah: return 0.8  // 0.5% UAH Deposit/Widthdrawal + 1 USDT Deposit/Widthdrawal + 0.2 % SPOT comission
            case .btc_uah:  return 0.8 // 0.5% UAH Deposit/Widthdrawal + Cheap BTC Deposit/Widthdrawal + 0.2 % SPOT comission
            }
        }
        
    }
    
    // MARK: - BTCTrade
    
    enum BTCTrade {
        
        case usdt_uah
        
        var paymentMethod: PaymentMethod {
            switch self {
            case .usdt_uah: return .btcTrade(.usdt_uah)
            }
        }
        
        var mainAsset: Currency {
            switch self {
            case .usdt_uah: return .usdt
            }
        }
        
        // in percents
        var sellCommission: Double {
            switch self {
            case .usdt_uah: return 1.35 // 1 USDT for Deposit + 0.05% Spot + 1.2% UAH Withdrawal
            }
        }
        
        // in percents
        var buyCommission: Double {
            switch self {
            case .usdt_uah: return 2.35  // 2.2% UAH Deposit + 0.05%Spot + 3 USDT Withdrawal
            }
        }
        
    }
    
    // MARK: - Minfin
    
    enum Minfin {
        
        case usd_uah
        case eur_uah
        
        var paymentMethod: PaymentMethod {
            switch self {
            case .usd_uah: return .minfin(.usd)
            case .eur_uah:  return .minfin(.eur)
            }
        }
        
        var mainAsset: Currency {
            switch self {
            case .usd_uah: return .usd
            case .eur_uah:  return .eur
            }
        }
        
        // in percents
        var commissions: Double {
            return 0.0
        }
        
    }
    
    // MARK: - Cases
    
    case binance(Binance)
    case huobi(Huobi)
    case whiteBit(WhiteBit)
    case exmo(EXMO)
    case kuna(Kuna)
    case coinsbit(Coinsbit)
    case betconix(Betconix)
    case qmall(QMall)
    case btcTrade(BTCTrade)
    case minfin(Minfin)
    
    // MARK: - PARAMETERS
    
    var description: String {
        "\(self.mainAssetAPIDescription)(\(self.paymentMethodDescription))"
    }
    
    var descriptionWithSpaces: String {
        var data = self.description
        switch self {
        case .binance(let binanceOpportunity):
            switch binanceOpportunity {
            case .p2p:    data.append("    ")
            case .spot:   data.append(" ")
            }
        case .whiteBit:   data.append("        ")
        case .huobi:      data.append("            ")
        case .exmo:       data.append("            ")
        case .kuna:       data.append("            ")
        case .coinsbit:   data.append("        ")
        case .betconix:   data.append("        ")
        case .qmall:      data.append("            ")
        case .btcTrade:   data.append("     ")
        case .minfin:     data.append("     ")
        }
        return data
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
        case .coinsbit(let coinsbitOpportunity):
            return coinsbitOpportunity.paymentMethod.description
        case .betconix(let betconixOpportunity):
            return betconixOpportunity.paymentMethod.description
        case .qmall(let qmallOpportunity):
            return qmallOpportunity.paymentMethod.description
        case .btcTrade(let btcTradeOpportunity):
            return btcTradeOpportunity.paymentMethod.description
        case .minfin(let minfinOpportunity):
            return minfinOpportunity.paymentMethod.description
        }
    }
    
    var mainAssetAPIDescription: String {
        switch self {
        case .binance(let binanceOpportunity):
            switch binanceOpportunity {
            case .p2p(let binanceP2POpportunity):
                return binanceP2POpportunity.mainAsset.apiDescription
            case .spot(let binanceSpotOpportunity):
                return binanceSpotOpportunity.mainAsset.apiDescription
            }
        case .whiteBit(let opportunity):
            return opportunity.mainAsset.apiDescription
        case .huobi(let opportunity):
            return opportunity.mainAsset.apiDescription
        case .exmo(let exmoOpportunity):
            return exmoOpportunity.mainAsset.apiDescription
        case .kuna(let kunaOpportunity):
            return kunaOpportunity.mainAsset.apiDescription
        case .coinsbit(let coinsbitOpportunity):
            return coinsbitOpportunity.mainAsset.apiDescription
        case .betconix(let betconixOpportunity):
            return betconixOpportunity.mainAsset.apiDescription
        case .qmall(let qmallOpportunity):
            return qmallOpportunity.mainAsset.apiDescription
        case .btcTrade(let btcTradeOpportunity):
            return btcTradeOpportunity.mainAsset.apiDescription
        case .minfin(let minfinOpportunity):
            return minfinOpportunity.mainAsset.apiDescription
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
                return binanceSpotOpportunity.sellCommission
            }
        case .whiteBit(let opportunity):
            return opportunity.sellCommission
        case .huobi(let opportunity):
            return opportunity.sellCommission
        case .exmo(let exmoOpportunity):
            return exmoOpportunity.sellCommission
        case .kuna(let kunaOpportunity):
            return kunaOpportunity.commission
        case .coinsbit(let coinsbitOpportunity):
            return coinsbitOpportunity.commissions
        case .betconix(let betconixOpportunity):
            return betconixOpportunity.sellCommission
        case .qmall(let qmallOpportunity):
            return qmallOpportunity.commissions
        case .btcTrade(let btcTradeOpportunity):
            return btcTradeOpportunity.sellCommission
        case .minfin(let minfinOpportunity):
            return minfinOpportunity.commissions
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
                return binanceSpotOpportunity.buyCommission
            }
        case .whiteBit(let opportunity):
            return opportunity.buyCommission
        case .huobi(let opportunity):
            return opportunity.buyCommission
        case .exmo(let exmoOpportunity):
            return exmoOpportunity.buyCommission
        case .kuna(let kunaOpportunity):
            return kunaOpportunity.commission
        case .coinsbit(let coinsbitOpportunity):
            return coinsbitOpportunity.commissions
        case .betconix(let betconixOpportunity):
            return betconixOpportunity.buyCommission
        case .qmall(let qmallOpportunity):
            return qmallOpportunity.commissions
        case .btcTrade(let btcTradeOpportunity):
            return btcTradeOpportunity.buyCommission
        case .minfin(let minfinOpportunity):
            return minfinOpportunity.commissions
        }
    }
    
}
