//
//  SurfaceResult.swift
//  
//
//  Created by Ruslan on 13.09.2022.
//

import Foundation

struct SurfaceResult: CustomStringConvertible, Hashable {
    
    enum Direction: String {
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
    
    var contractsDescription: String {
        "\(contract1)_\(contract2)_\(contract3)"
    }
    
    var shortDescription: String {
        String("""
        \(modeDescrion) \(direction) \(contract1) \(contract2) \(contract3)
        Step 1: Swap \(swap0) at \(swap1Rate.string()) for \(swap1) acquiring \(acquiredCoinT1.string())
        Step 2: Swap \(swap1) at \(swap2Rate.string()) for \(swap2) acquiring \(acquiredCoinT2.string())
        Step 3: Swap \(swap2) at \(swap3Rate.string()) for \(swap3) acquiring \(acquiredCoinT3.string())
        """)
    }
    
    var description: String {
        String("""
        \(shortDescription)
        Profit: \(profitPercent.string()) %\n
        """)
    }
    
}
