//
//  Extensions.swift
//  
//
//  Created by Ruslan Popesku on 29.06.2022.
//

import Foundation

extension NSNumber {
    
    func toLocalCurrency(fractDigits: Int = 2) -> String? {
        String(format: "%.2f", Double(truncating: self))
    }

}

extension Numeric {
    
    func toLocalCurrency(fractDigits: Int = 2) -> String {
        (self as? NSNumber)?.toLocalCurrency(fractDigits: fractDigits) ?? "NaN"
    }
    
}
