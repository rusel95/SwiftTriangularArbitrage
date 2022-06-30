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
    
    struct MarketData: Codable {
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
        symbol: Symbol = .usdtuah,
        completion: @escaping(_ asks: [Double], _ bids: [Double], _ error: Error?) -> Void
    ) {
        var urlComponents = URLComponents(string: "https://api.huobi.pro/market/depth")!
        urlComponents.queryItems = [
            URLQueryItem(name: "symbol", value: symbol.rawValue),
            URLQueryItem(name: "type", value: "step0")
        ]
        let request = URLRequest(url: urlComponents.url!)
        URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
            if let error = error {
                print("error is \(error.localizedDescription)")
                completion([], [], error)
                return
            }
            
            guard let data = data, let marketData = try? JSONDecoder().decode(MarketData.self, from: data) else { return }
            
            let asks = marketData.tick.asks.compactMap { $0.first }.compactMap { Double($0) }
            let bids = marketData.tick.bids.compactMap { $0.first }.compactMap { Double($0) }
            completion(asks, bids, nil)
        }).resume()
    }
    
}

