//
//  SurfaceResult.swift
//  
//
//  Created by Ruslan on 13.09.2022.
//

import Foundation

struct SurfaceResult: CustomStringConvertible {
    
    enum Direction: String {
        case forward
        case reverse
    }
    
    let swap0: String // starting coin
    let swap1: String
    let swap2: String
    let swap3: String
    let contract1: String
    let contract2: String
    let contract3: String
    let directionTrade1: String
    let directionTrade2: String
    let directionTrade3: String
    let acquiredCoinT1: Double
    let acquiredCoinT2: Double
    let acquiredCoinT3: Double
    let swap1Rate: Double
    let swap2Rate: Double
    let swap3Rate: Double
    let profitPercent: Double
    let direction: Direction
    
    var description: String {
        String("""
                  \(direction) \(contract1) \(contract2) \(contract3)
                  Step 1: Start with \(swap0) of \(1.0) Swap at \(swap1Rate.string()) for \(swap1) acquiring \(acquiredCoinT1.string())
                  Step 2: Swap \(acquiredCoinT1.string()) of \(swap1) at \(swap2Rate.string()) for \(swap2) acquiring \(acquiredCoinT2.string())
                  Step 3: Swap \(acquiredCoinT2.string()) of \(swap2) at \(swap3Rate.string()) for \(swap3) acquiring \(acquiredCoinT3.string())
                  Profit: \(profitPercent.string()) %\n
                  """)
    }
    
}
