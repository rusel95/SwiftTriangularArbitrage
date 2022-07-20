//
//  TokenReader.swift
//  
//
//  Created by Ruslan Popesku on 28.06.2022.
//

import Foundation

extension String {
    
    /// Reads token from environment variable or from a file.
    ///
    /// - Returns: token
    static func readToken(from name: String) -> String {
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
    static func readConfigurationValue(_ name: String) -> String? {
        let token = ProcessInfo.processInfo.environment[name] ?? (try? String(contentsOfFile: name, encoding: String.Encoding.utf8))
        return token?.trimmingCharacters(in: NSCharacterSet.whitespacesAndNewlines)
    }
    
    /// Reads value from environment variable or from a file.
    ///
    /// - Returns: `Int64`
    static func readConfigurationValue(_ name: String) -> Int64? {
        if let v: String = readConfigurationValue(name) {
            return Int64(v)
        }
        return nil
    }
    
    /// Reads value from environment variable or from a file.
    ///
    /// - Returns: `Int`
    static func readConfigurationValue(_ name: String) -> Int? {
        if let v: String = readConfigurationValue(name) {
            return Int(v)
        }
        return nil
    }
    
}
