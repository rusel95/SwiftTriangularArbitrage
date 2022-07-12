//
//  PaymentMethod.swift
//  
//
//  Created by Ruslan Popesku on 30.06.2022.
//

enum PaymentMethod: Equatable {
    
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
                case .privatbank: return "Privat"
                case .monobank: return "Mono"
                case .pumb: return "PUMB"
                case .abank: return "ABank"
                case .wise: return "Wise"
                case .binancePayUAH: return "Fiat"
                }
            }
        }
        
        enum Spot: String {
            
            case usdtUAH = "USDTUAH"
            
            var shortDescription: String {
                switch self {
                case .usdtUAH: return "BinSpotUSDTUAH"
                }
            }
        }
        
        case p2p(P2P)
        case spot(Spot)
        
    }
    
    enum WhiteBit: String {
        
        case usdtuahSpot = "USDT_UAH"
        
        var description: String {
            switch self {
            case .usdtuahSpot: return "wb_Sp"
            }
        }
    }
    
    enum Huobi: String {
        case usdtuahSpot = "usdtuah"
        
        var description: String {
            switch self {
            case .usdtuahSpot: return "hu_Sp"
            }
        }
    }
    
    case binance(Binance)
    case huobi(Huobi)
    case whiteBit(WhiteBit)
    
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
        }
    }
    
}
