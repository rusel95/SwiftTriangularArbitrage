//
//  Utils.swift
//  
//
//  Created by Ruslan Popesku on 28.06.2022.
//

import Foundation

/// Reads token from environment variable or from a file.
///
/// - Returns: token
func readToken(from name: String) -> String {
    guard let token: String = readConfigurationValue(name) else {
        print("\n" +
            "-----\n" +
            "ERROR\n" +
            "-----\n" +
            "Please create either:\n" +
            "  - an environment variable named \(name)\n" +
            "  - a file named \(name)\n" +
            "containing your bot's token.\n\n")
        exit(1)
    }
    return token
}

/// Reads value from environment variable or from a file.
///
/// - Returns: `String`
func readConfigurationValue(_ name: String) -> String? {
    let environment = ProcessInfo.processInfo.environment
    var value = environment[name]
    if value == nil {
        value = try? String(contentsOfFile: name, encoding: String.Encoding.utf8)
    }
    return value?.trimmingCharacters(in: NSCharacterSet.whitespacesAndNewlines)
}

/// Reads value from environment variable or from a file.
///
/// - Returns: `Int64`
func readConfigurationValue(_ name: String) -> Int64? {
    if let v: String = readConfigurationValue(name) {
        return Int64(v)
    }
    return nil
}

/// Reads value from environment variable or from a file.
///
/// - Returns: `Int`
func readConfigurationValue(_ name: String) -> Int? {
    if let v: String = readConfigurationValue(name) {
        return Int(v)
    }
    return nil
}
