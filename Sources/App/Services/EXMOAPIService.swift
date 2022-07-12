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

final class EXMOAPIService {
    
    // MARK: - STRUCTS
    
    struct Welcome: Codable {
        
        let usdtUah: Pair

        enum CodingKeys: String, CodingKey {
            case usdtUah = "USDT_UAH"
        }
        
    }
    
    struct Pair: Codable {
        
        let askQuantity, askAmount, askTop, bidQuantity: String
        let bidAmount, bidTop: String
        let ask: [[String]]
        let bid: [[String]]

        enum CodingKeys: String, CodingKey {
            case askQuantity = "ask_quantity"
            case askAmount = "ask_amount"
            case askTop = "ask_top"
            case bidQuantity = "bid_quantity"
            case bidAmount = "bid_amount"
            case bidTop = "bid_top"
            case ask, bid
        }
        
    }

    
    // MARK: - PROPERTIES
    
    static let shared = EXMOAPIService()

    // MARK: - METHODS
    
    func getOrderbook(
        paymentMethod: String,
        completion: @escaping(_ askTop: Double?, _ bidTop: Double?, _ error: Error?) -> Void
    ) {
        var urlComponents = URLComponents(string: "https://api.exmo.com/v1.1/order_book")!
        urlComponents.queryItems = [
            URLQueryItem(name: "pair", value: paymentMethod),
            URLQueryItem(name: "limit", value: "5")
        ]
        let request = URLRequest(url: urlComponents.url!)
        URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
            if let error = error {
                print("error is \(error.localizedDescription)")
                completion(nil, nil, error)
                return
            }
            
            guard let data = data,
                  let welcome = try? JSONDecoder().decode(Welcome.self, from: data) else {
                completion(nil, nil, nil)
                return }
        
            completion(Double(welcome.usdtUah.askTop), Double(welcome.usdtUah.bidTop), nil)
        }).resume()
    }
    
}

