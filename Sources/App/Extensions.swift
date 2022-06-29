//
//  Extensions.swift
//  
//
//  Created by Ruslan Popesku on 29.06.2022.
//

//extension FloatingPoint {
//
//    var prettyPrinted: String {
//        String(format: "%.2f", self)
//    }
//
//}

import Foundation

extension NSNumber {
    
    func toLocalCurrency(fractDigits: Int = 2) -> String? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = fractDigits
        return formatter.string(from: self)
    }

}

extension Numeric {
    
    func toLocalCurrency(fractDigits: Int = 2) -> String {
        (self as? NSNumber)?.toLocalCurrency(fractDigits: fractDigits) ?? "NaN"
    }
    
}
