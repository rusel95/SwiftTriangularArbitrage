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

extension URL {
    
    static var documentsDirectory: URL {
        URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)")
    }
    
}


extension Date {
                    
    static func - (lhs: Date, rhs: Date) -> TimeInterval {
        lhs.timeIntervalSinceReferenceDate - rhs.timeIntervalSinceReferenceDate
    }
    
    var readableDescription: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm:ss"
        dateFormatter.locale = Locale(identifier: "UA_ua")
        return dateFormatter.string(from: self)
    }
    
    var fullDateReadableDescription: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM-dd-yyyy HH:mm"
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

extension Array where Element: FloatingPoint {
    
    func averageIncr() -> Element {
        enumerated().reduce(Element(0)) { $0 + ( $1.1 - $0 ) / Element($1.0 + 1) }
    }
    
}

extension Date {
    
    var millisecondsSince1970:Int64 {
        Int64((self.timeIntervalSince1970 * 1000.0).rounded())
    }
    
    init(milliseconds:Int64) {
        self = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }
    
}

extension URL {
    func appending(_ queryItem: String, value: String?) -> URL {
        guard var urlComponents = URLComponents(string: absoluteString) else {
            return absoluteURL
        }

        var queryItems: [URLQueryItem] = urlComponents.queryItems ??  []
        let queryItem = URLQueryItem(name: queryItem, value: value)
        queryItems.append(queryItem)
        urlComponents.queryItems = queryItems
        // a fix for a special case of encoding + in query parameters
        urlComponents.percentEncodedQuery = urlComponents.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        guard let url = urlComponents.url else {
            fatalError("The url should be constructed")
        }
        return url
    }
}


extension Double {
    
    func roundToDecimal(_ fractionDigits: Int) -> Double {
        let multiplier = pow(10, Double(fractionDigits))
        return (self * multiplier).rounded() / multiplier
    }
    
}

extension String {
    
    func getMemoryUsedMegabytes() -> String {
        // https://stackoverflow.com/questions/5887248/ios-app-maximum-memory-budget/19692719#19692719
        // https://stackoverflow.com/questions/27556807/swift-pointer-problems-with-mach-task-basic-info/27559770#27559770
        
        var used_megabytes: Float = 0
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }
        if kerr == KERN_SUCCESS {
            let used_bytes: Float = Float(info.resident_size)
            used_megabytes = used_bytes / 1024.0 / 1024.0
        }
        return "\(used_megabytes) mb"
    }
    
}
