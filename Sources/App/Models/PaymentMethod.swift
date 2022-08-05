//
//  PaymentMethod.swift
//  
//
//  Created by Ruslan Popesku on 30.06.2022.
//

enum PaymentMethod: Equatable {
    
    // MARK: - BINANCE
    
    enum Binance: Equatable {
        
        enum P2P: String {
            case privatbank = "Privatbank"
            case monobank = "Monobank"
            case pumb = "PUMBBank"
            case abank = "ABank"
            case wise = "Wise"
            case binancePayUAH = "UAHfiatbalance"
            
            var shortDescription: String {
                switch self {
                case .privatbank:      return "P2P_Privat"
                case .monobank:        return "P2P_Mono"
                case .pumb:            return "P2P_PUMB"
                case .abank:           return "P2P_ABank"
                case .wise:            return "P2P_Wise"
                case .binancePayUAH:   return "P2P_Fiat"
                }
            }
        }
        
        enum Spot: String {
            
            case usdtuah =  "USDTUAH"
            case btcuah =   "BTCUAH"
            
            var shortDescription: String {
                switch self {
                case .usdtuah: return "BinanceSpot"
                case .btcuah:  return "BinanceSpot"
                }
            }
        }
        
        case p2p(P2P)
        case spot(Spot)
        
    }
    
    // MARK: - WhiteBit
    
    enum WhiteBit: String {
        
        case usdt_uah = "USDT_UAH"
        case btc_uah = "BTC_UAH"
        
        var description: String {
            switch self {
            case .usdt_uah: return "WhiteBit"
            case .btc_uah: return "WhiteBit"
            }
        }
    }
    
    // MARK: - Huobi
    
    enum Huobi: String {
        case usdt_uah = "usdtuah"
        case btc_uah = "btcuah"
        
        var description: String {
            return "Huobi"
        }
    }
    
    // MARK: - EXMO
    
    enum EXMO: String {
        
        case usdt_uah = "USDT_UAH"
        case btc_uah  = "BTC_UAH"
        
        var description: String {
            return "EXMO"
        }
    }
    
    // MARK: - KUNA
    
    enum Kuna: String {
        
        case usdt_uah = "USDTUAH"
        case btc_uah = "BTCUAH"
        
        var description: String {
            "KUNA"
        }
    }
    
    // MARK: - Coinsbit
    
    enum Coinsbit: String {
        
        case usdt_uah = "USDT_UAH"
        case btc_uah = "BTC_UAH"
        
        var description: String {
            "Coinsbit"
        }
    }
    
    // MARK: - Betconix
    
    enum Betconix: String {
        
        case usdt_uah = "usdt_uah"
        case btc_uah  = "btc_uah"
        
        var description: String {
            "Betconix"
        }
    }
    
    // MARK: - BTCTrade
    
    enum BTCTrade: String {
        
        case usdt_uah = "usdt_uah"
        
        var description: String {
            "BTCTrade"
        }
    }
    
    case binance(Binance)
    case huobi(Huobi)
    case whiteBit(WhiteBit)
    case exmo(EXMO)
    case kuna(Kuna)
    case coinsbit(Coinsbit)
    case betconix(Betconix)
    case minfin(MinfinService.AuctionType)
    case btcTrade(BTCTrade)
    
    var apiDescription: String {
        switch self {
        case .binance(let binancePaymentMethod):
            switch binancePaymentMethod {
            case .p2p(let p2pPaymentMethod):
                return p2pPaymentMethod.rawValue
            case .spot(let binanceSpot):
                return binanceSpot.rawValue
            }
        case .whiteBit(let paymentMethod):
            return paymentMethod.rawValue
        case .huobi(let paymentMethod):
            return paymentMethod.rawValue
        case .exmo(let paymentMethod):
            return paymentMethod.rawValue
        case .kuna(let paymentMethod):
            return paymentMethod.rawValue
        case .coinsbit(let paymentMethod):
            return paymentMethod.rawValue
        case .betconix(let paymentMethod):
            return paymentMethod.rawValue
        case .minfin(let paymentMethod):
            return paymentMethod.rawValue
        case .btcTrade(let paymentMethod):
            return paymentMethod.rawValue
        }
    }
    
    var description: String {
        switch self {
        case .binance(let binancePaymentMethod):
            switch binancePaymentMethod {
            case .p2p(let p2pPaymentMethod):
                return p2pPaymentMethod.shortDescription
            case .spot(let binanceSpot):
                return binanceSpot.shortDescription
            }
        case .whiteBit(let paymentMethod):
            return paymentMethod.description
        case .huobi(let paymentMethod):
            return paymentMethod.description
        case .exmo(let paymentMethod):
            return paymentMethod.description
        case .kuna(let paymentMethod):
            return paymentMethod.description
        case .coinsbit(let paymentMethod):
            return paymentMethod.description
        case .betconix(let paymentMethod):
            return paymentMethod.description
        case .minfin(let paymentMethod):
            return paymentMethod.description
        case .btcTrade(let paymentMethod):
            return paymentMethod.description
        }
    }
    
}
