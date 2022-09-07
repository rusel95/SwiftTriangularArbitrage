//
//  File.swift
//  
//
//  Created by Ruslan on 07.09.2022.
//

import Foundation

extension Double {
    
    func string(minFractionDigits: Int = 0, maxFractionDigits: Int = 5) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = minFractionDigits
        formatter.maximumFractionDigits = maxFractionDigits
        return formatter.string(from: self as NSNumber) ?? "\(self)"
    }
    
}
