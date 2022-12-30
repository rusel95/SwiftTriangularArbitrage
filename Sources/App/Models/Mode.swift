//
//  Common.swift
//  
//
//  Created by Ruslan on 29.12.2022.
//

enum Mode {
    
    case standart
    case stable
    
    var description: String {
        switch self {
        case .standart:
            return "[Standart]"
        case .stable:
            return "[Stable]"
        }
    }
    
    var interestingProfitabilityPercent: Double {
        switch self {
        case .standart:
#if DEBUG
            return 0.1
#else
            return 0.3
#endif
        case .stable:
#if DEBUG
            return 0.0
#else
            return 0.2
#endif
        }
    }
}
