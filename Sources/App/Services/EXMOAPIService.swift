//
//  EXMOAPIService.swift
//  
//
//  Created by Ruslan Popesku on 12.07.2022.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Logging

final class EXMOAPIService {
    
    // MARK: - STRUCTS
    
    struct Pair: Codable {
        
//        let askQuantity, askAmount: String
        let askTop: String
//        let bidQuantity: String
//        let bidAmount: String
        let bidTop: String
//        let ask: [[String]]
//        let bid: [[String]]

        enum CodingKeys: String, CodingKey {
//            case askQuantity = "ask_quantity"
//            case askAmount = "ask_amount"
            case askTop = "ask_top"
//            case bidQuantity = "bid_quantity"
//            case bidAmount = "bid_amount"
            case bidTop = "bid_top"
//            case ask, bid
        }
        
    }

    
    // MARK: - PROPERTIES
    
    static let shared = EXMOAPIService()
    
    private var logger = Logger(label: "api.exmo")

    // MARK: - METHODS
    
    func getOrderbook(
        assetsPair: String,
        completion: @escaping(_ askTop: Double?, _ bidTop: Double?, _ error: Error?) -> Void
    ) {
        var urlComponents = URLComponents(string: "https://api.exmo.com/v1.1/order_book")!
        urlComponents.queryItems = [
            URLQueryItem(name: "pair", value: assetsPair),
            URLQueryItem(name: "limit", value: "5")
        ]
        let request = URLRequest(url: urlComponents.url!)
        URLSession.shared.dataTask(with: request, completionHandler: { [weak self] data, response, error in
            if let error = error {
                self?.logger.warning(Logger.Message(stringLiteral: error.localizedDescription))
                completion(nil, nil, error)
                return
            }
            
            guard let data = data else {
                self?.logger.warning(Logger.Message(stringLiteral: "NO DATA FOR EXMO, url: \(urlComponents.debugDescription)"))
                completion(nil, nil, nil)
                return
            }
            
            do {
                let jsonData = try JSONDecoder().decode(([String: Pair]).self, from: data)
                let pair = jsonData[assetsPair]
                completion(Double(pair?.askTop ?? ""), Double(pair?.bidTop ?? ""), nil)
            } catch (let decodingError) {
                self?.logger.error(Logger.Message(stringLiteral: decodingError.localizedDescription))
                completion(nil, nil, decodingError)
            }
        }).resume()
    }
    
}

