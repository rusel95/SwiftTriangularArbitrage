//
//  BetconixAPIService.swift
//  
//
//  Created by Ruslan Popesku on 28.07.2022.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Logging

final class BetconixAPIService {
    
    // MARK: - STRUCTS

    struct Welcome: Codable {
        let pair: String
        let ask, bid: [Ask]
        let askQuantity: Int
        let askAmount, askTop: Double
        let bidQuantity: Int
        let bidAmount, bidTop: Double

        enum CodingKeys: String, CodingKey {
            case pair, ask, bid
            case askQuantity = "ask_quantity"
            case askAmount = "ask_amount"
            case askTop = "ask_top"
            case bidQuantity = "bid_quantity"
            case bidAmount = "bid_amount"
            case bidTop = "bid_top"
        }
    }

    struct Ask: Codable {
        let collapsed: Int
        let price, quantity, quantityLeft, total: String

        enum CodingKeys: String, CodingKey {
            case collapsed, price, quantity
            case quantityLeft = "quantity_left"
            case total
        }
    }

    // MARK: - PROPERTIES
    
    static let shared = BetconixAPIService()
    
    private var logger = Logger(label: "api.betconix")
    
    private init() {}

    // MARK: - METHODS
    
    func getOrderbook(
        assetsPair: String,
        completion: @escaping(_ ask: Double?, _ bid: Double?, _ error: Error?) -> Void
    ) {
        let url = URL(string: "https://betconix.com/api/public/order_book/\(assetsPair)")!
        let request = URLRequest(url: url)
        URLSession.shared.dataTask(with: request, completionHandler: { [weak self] data, response, error in
            if let error = error {
                self?.logger.warning(Logger.Message(stringLiteral: error.localizedDescription))
                completion(nil, nil, error)
                return
            }
            
            guard let data = data else {
                self?.logger.warning(Logger.Message(stringLiteral: "NO Data for Betconix: \(url.debugDescription)"))
                completion(nil, nil, nil)
                return
            }
            
            do {
               let responseBody = try JSONDecoder().decode(Welcome.self, from: data)
                completion(responseBody.askTop, responseBody.bidTop, nil)
            } catch (let decodingError) {
                self?.logger.error(Logger.Message(stringLiteral: decodingError.localizedDescription))
                completion(nil, nil, decodingError)
            }
        }).resume()
    }
    
}

