//
//  Extensions.swift
//  
//
//  Created by Ruslan Popesku on 29.06.2022.
//

import Foundation

extension NSNumber {
    
    func toLocalCurrency(fractDigits: Int = 2) -> String? {
        String(format: "%.\(fractDigits)f", Double(truncating: self))
    }

}

extension Numeric {
    
    func toLocalCurrency(fractDigits: Int = 2) -> String {
        (self as? NSNumber)?.toLocalCurrency(fractDigits: fractDigits) ?? "NaN"
    }
    
}

extension Date {
                    
    static func - (lhs: Date, rhs: Date) -> TimeInterval {
        return lhs.timeIntervalSinceReferenceDate - rhs.timeIntervalSinceReferenceDate
    }
    
    var readableDescription: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"
        dateFormatter.locale = Locale(identifier: "UA_ua")
        return dateFormatter.string(from: self)
    }
                    
}

extension Double {
    
    func string(minFractionDigits: Int = 0, maxFractionDigits: Int = 5) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = minFractionDigits
        formatter.maximumFractionDigits = maxFractionDigits
        return formatter.string(from: self as NSNumber) ?? "\(self)"
    }
    
}

extension Array {
    
    func toDictionary<Key: Hashable>(with selectKey: (Element) -> Key) -> [Key:Element] {
        var dict = [Key:Element]()
        for element in self {
            dict[selectKey(element)] = element
        }
        return dict
    }
    
}
