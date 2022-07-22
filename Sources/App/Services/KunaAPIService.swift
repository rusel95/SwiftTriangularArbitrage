//
//  KunaAPIService.swift
//  
//
//  Created by Ruslan Popesku on 12.07.2022.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Logging

final class KunaAPIService {
    
    // MARK: - Structs
    
    struct Order {
        let price: Double
        let volume: Double
        let amountOfDeals: Int
    }
    
    // MARK: - PROPERTIES
    
    static let shared = KunaAPIService()
    
    private var logger = Logger(label: "api.kuna")
    
    // MARK: - METHODS
    
    func getOrderbook(
        paymentMethod: String,
        completion: @escaping(_ asks: [Double], _ bids: [Double], _ error: Error?) -> Void
    ) {
        let url = URL(string: "https://api.kuna.io/v3/book/\(paymentMethod)")!
        URLSession.shared.dataTask(with: url, completionHandler: { [weak self] data, response, error in
            if let error = error {
                self?.logger.warning(Logger.Message(stringLiteral: error.localizedDescription))
                completion([], [], error)
                return
            }
            
            guard let data = data else {
                self?.logger.warning(Logger.Message(stringLiteral: "NO Data for KUNA \(url.debugDescription)"))
                completion ([], [], nil)
                return
            }
            
            do {
                let rawOrderbook = try JSONDecoder().decode([[Double]].self, from: data)
                let orders = rawOrderbook
                    .filter { $0.count == 3 }
                    .map { Order(price: $0[0], volume: $0[1], amountOfDeals: Int($0[2])) }
                
                let bids = orders.filter { $0.volume > 0 }.map { $0.price }.sorted { $0 > $1 }
                let asks = orders.filter { $0.volume < 0 }.map { $0.price }.sorted { $0 < $1 }
                completion(asks, bids, nil)
            } catch (let decodingError) {
                self?.logger.warning(Logger.Message(stringLiteral: decodingError.localizedDescription))
                completion([], [], decodingError)
            }
        }).resume()
    }
    
}

