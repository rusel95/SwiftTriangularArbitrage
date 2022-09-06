//
//  CoinsbitAPIService.swift
//  
//
//  Created by Ruslan Popesku on 26.07.2022.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Logging

final class CoinsbitAPIService {
    
    // MARK: - STRUCTS
    
    struct ResponseBody: Codable {
//        let code: Int
//        let success: Bool
//        let message: String
        let result: Result
    }

    // MARK: - Result
    struct Result: Codable {
        let name, bid, ask: String
    }
    
    // MARK: - PROPERTIES
    
    static let shared = CoinsbitAPIService()
    
    private var logger = Logger(label: "api.coinsbit")

    // MARK: - METHODS
    
    func getTicker(
        market: String,
        completion: @escaping(_ ask: Double?, _ bid: Double?, _ error: Error?) -> Void
    ) {
        let url = URL(string: "https://api.coinsbit.io/api/v1/public/ticker?market=\(market)")!
        let request = URLRequest(url: url)
        URLSession.shared.dataTask(with: request, completionHandler: { [weak self] data, response, error in
            if let error = error {
                self?.logger.warning(Logger.Message(stringLiteral: error.localizedDescription))
                completion(nil, nil, error)
                return
            }
            
            guard let data = data else {
                self?.logger.warning(Logger.Message(stringLiteral: "NO Data for Coinsbit: \(url.debugDescription)"))
                completion(nil, nil, nil)
                return
            }
            
            do {
               let responseBody = try JSONDecoder().decode(ResponseBody.self, from: data)
               completion(Double(responseBody.result.ask), Double(responseBody.result.ask), nil)
            } catch (let decodingError) {
                self?.logger.error(Logger.Message(stringLiteral: decodingError.localizedDescription))
                completion(nil, nil, decodingError)
            }
        }).resume()
    }
    
}

