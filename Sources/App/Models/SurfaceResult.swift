//
//  SurfaceResult.swift
//  
//
//  Created by Ruslan on 13.09.2022.
//

import Foundation

struct SurfaceResult: Codable, CustomStringConvertible, Hashable {
    
    enum Direction: String, Codable {
        case forward
        case reverse
    }
    
    let modeDescrion: String
    
    let swap0: String // starting coin
    let swap1: String
    let swap2: String
    let swap3: String
    
    let contract1: String
    let contract2: String
    let contract3: String
    
    let directionTrade1: OrderSide
    let directionTrade2: OrderSide
    let directionTrade3: OrderSide
    
    let acquiredCoinT1: Double
    let acquiredCoinT2: Double
    let acquiredCoinT3: Double
    
    let swap1Rate: Double
    let swap2Rate: Double
    let swap3Rate: Double
    
    let profitPercent: Double
    let direction: Direction
    
    var pairAExpectedPrice: Double {
        switch directionTrade1 {
        case .quoteToBase:
            return 1.0 / swap1Rate
        case .baseToQuote:
            return swap1Rate
        case .unknown:
            return 0.0
        }
    }
    
    var step1Description: String {
        switch directionTrade1 {
        case .quoteToBase:
            return "Buy \(swap1) at \(pairAExpectedPrice.string(maxFractionDigits: 10)) for \(swap0) acquiring \(acquiredCoinT1.string(maxFractionDigits: 10))"
        case .baseToQuote:
            return "Sell \(swap0) at \(pairAExpectedPrice.string(maxFractionDigits: 10)) for \(swap1) acquiring \(acquiredCoinT1.string(maxFractionDigits: 10))"
        case .unknown:
            return "unknown"
        }
    }
    
    var pairBExpectedPrice: Double {
        switch directionTrade2 {
        case .quoteToBase:
            return 1.0 / swap2Rate
        case .baseToQuote:
            return swap2Rate
        case .unknown:
            return 0.0
        }
    }
    
    var step2Description: String {
        switch directionTrade2 {
        case .quoteToBase:
            return "Buy \(swap2) at \(pairBExpectedPrice.string(maxFractionDigits: 10)) for \(swap1) acquiring \(acquiredCoinT2.string(maxFractionDigits: 10))"
        case .baseToQuote:
            return "Sell \(swap1) at \(pairBExpectedPrice.string(maxFractionDigits: 10)) for \(swap2) acquiring \(acquiredCoinT2.string(maxFractionDigits: 10))"
        case .unknown:
            return "unknown"
        }
    }
    
    var pairCExpectedPrice: Double {
        switch directionTrade3 {
        case .quoteToBase:
            return 1.0 / swap3Rate
        case .baseToQuote:
            return swap3Rate
        case .unknown:
            return 0.0
        }
    }
    
    var step3Description: String {
        switch directionTrade3 {
        case .quoteToBase:
            return "Buy \(swap3) at \(pairCExpectedPrice.string(maxFractionDigits: 10)) for \(swap2) acquiring \(acquiredCoinT3.string(maxFractionDigits: 10))"
        case .baseToQuote:
            return "Sell \(swap2) at \(pairCExpectedPrice.string(maxFractionDigits: 10)) for \(swap3) acquiring \(acquiredCoinT3.string(maxFractionDigits: 10))"
        case .unknown:
            return "unknown"
        }
    }
    
    var contractsDescription: String {
        "\(contract1)_\(contract2)_\(contract3)"
    }
    
    var shortDescription: String {
        String("""
        \(modeDescrion) \(direction) \(contract1) \(contract2) \(contract3)
        Step 1: \(step1Description)
        Step 2: \(step2Description)
        Step 3: \(step3Description)
        """)
    }
    
    var description: String {
        String("""
        \(shortDescription)
        Profit: \(profitPercent.string(maxFractionDigits: 2)) %\n
        """)
    }
    
}
