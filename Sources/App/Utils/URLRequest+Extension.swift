//
//  URLRequest+Extension.swift
//  
//
//  Created by Ruslan on 21.12.2022.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Crypto

extension URLRequest {
    
    mutating func addApiKeyHeader(apiKeyString: String) -> Void {
        self.addValue(apiKeyString, forHTTPHeaderField: "X-MBX-APIKEY")
    }
    
    mutating func sign(apiKeyString: String, secretString: String) -> Void {
        self.addApiKeyHeader(apiKeyString: apiKeyString)
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        self.url = self.url?.appending("timestamp", value: "\(timestamp)")
        guard let query = self.url?.query else {
            fatalError("query should be here!")
        }
        let symmetricKey = SymmetricKey(data: secretString.data(using: .utf8)!)
        let signature = HMAC<SHA256>.authenticationCode(for: query.data(using: .utf8)!, using: symmetricKey)
        let signatureString = Data(signature).map { String(format: "%02hhx", $0) }.joined()
        self.url = self.url?.appending("signature", value: signatureString)
    }
    
}
