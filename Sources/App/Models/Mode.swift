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
    
}
