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

final class KunaAPIService {

    // MARK: - Structs

    struct Order {
        let price: Double
        let volume: Double
        let amountOfDeals: Int
    }
    
    // MARK: - PROPERTIES
    
    static let shared = KunaAPIService()

    // MARK: - METHODS
    
    func getOrderbook(
        paymentMethod: String,
        completion: @escaping(_ asks: [Double], _ bids: [Double], _ error: Error?) -> Void
    ) {
        let url = URL(string: "https://api.kuna.io/v3/book/\(paymentMethod)")!
        URLSession.shared.dataTask(with: url, completionHandler: { data, response, error in
            if let error = error {
                print("error is \(error.localizedDescription)")
                completion([], [], error)
                return
            }
            
            guard let data = data, let rawOrderbook = try? JSONDecoder().decode([[Double]].self, from: data) else {
                completion ([], [], nil)
                return
            }
            
            let orders = rawOrderbook
                .filter { $0.count == 3 }
                .map { Order(price: $0[0], volume: $0[1], amountOfDeals: Int($0[2])) }
            
            let bids = orders.filter { $0.volume > 0 }.map { $0.price }.sorted { $0 > $1 }
            let asks = orders.filter { $0.volume < 0 }.map { $0.price }.sorted { $0 < $1 }
            completion(asks, bids, nil)
        }).resume()
    }
    
}

