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
import Logging

final class HuobiAPIService {

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
    
    private var logger = Logger(label: "api.huobi")

    // MARK: - METHODS
    
    func getOrderbook(
        paymentMethod: String,
        completion: @escaping(_ asks: [Double], _ bids: [Double], _ error: Error?) -> Void
    ) {
        var urlComponents = URLComponents(string: "https://api.huobi.pro/market/depth")!
        urlComponents.queryItems = [
            URLQueryItem(name: "symbol", value: paymentMethod),
            URLQueryItem(name: "type", value: "step0")
        ]
        let request = URLRequest(url: urlComponents.url!)
        URLSession.shared.dataTask(with: request, completionHandler: { [weak self] data, response, error in
            if let error = error {
                self?.logger.error(Logger.Message(stringLiteral: error.localizedDescription))
                completion([], [], error)
                return
            }
            
            guard let data = data else {
                self?.logger.error(Logger.Message(stringLiteral: "NO DATA FOR HUOBI \(urlComponents.debugDescription)"))
                completion([], [], nil)
                return
            }
            
            do {
                let marketData = try JSONDecoder().decode(MarketData.self, from: data)
                let asks = marketData.tick.asks.compactMap { $0.first }.compactMap { Double($0) }
                let bids = marketData.tick.bids.compactMap { $0.first }.compactMap { Double($0) }
                completion(asks, bids, nil)
            } catch (let decodingError) {
                self?.logger.error(Logger.Message(stringLiteral: decodingError.localizedDescription))
                completion([], [], decodingError)
            }
        }).resume()
    }
    
}

