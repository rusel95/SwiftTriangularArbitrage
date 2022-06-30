//
//  File.swift
//  
//
//  Created by Ruslan Popesku on 30.06.2022.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class HuobiAPIService {
    
    // MARK: - ENUMERATIONS
    
    enum Symbol: String {
        case usdtuah
    }

    // MARK: - Structs
    
    struct Response: Codable {
        let ch, status: String
        let ts: Int
        let tick: Tick
    }

    struct Tick: Codable {
        let bids, asks: [[Double]]
        let version, ts: Int
    }

    
    // MARK: - PROPERTIES
    
    static let shared = HuobiAPIService()

    // MARK: - METHODS
    
    func getOrderbook(
        for asset: Asset,
        completion: @escaping(_ asks: [Double]?, _ bids: [Double]?, _ error: Error?) -> Void
    ) {
        var urlComponents = URLComponents(string: "https://whitebit.com/api/v4/public/orderbook/\(asset.rawValue)")!
        urlComponents.queryItems = [
            URLQueryItem(name: "limit", value: "5")
        ]
        let request = URLRequest(url: urlComponents.url!)
        URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
            if let error = error {
                print("error is \(error.localizedDescription)")
                completion(nil, nil, error)
                return
            }
            
            guard let data = data else { return }
            
            let orderbookData = try? JSONDecoder().decode(OrderbookData.self, from: data)
            let asks = orderbookData?.asks.compactMap { $0.first }.compactMap { Double($0) }
            let bids = orderbookData?.bids.compactMap { $0.first }.compactMap { Double($0) }
            completion(asks, bids, nil)
        }).resume()
    }
    
}

