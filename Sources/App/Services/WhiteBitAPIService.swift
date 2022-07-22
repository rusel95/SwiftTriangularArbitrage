//
//  WhiteBitAPIService.swift
//  
//
//  Created by Ruslan Popesku on 27.06.2022.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Logging

final class WhiteBitAPIService {
    
    struct OrderbookData: Codable {
        
        let timestamp: Int
        let asks: [[String]]
        let bids: [[String]]
        
    }
    
    // MARK: - PROPERTIES
    
    static let shared = WhiteBitAPIService()
    
    private var logger = Logger(label: "api.whitebit")

    // MARK: - METHODS
    
    func getOrderbook(
        paymentMethod: String,
        completion: @escaping(_ asks: [Double]?, _ bids: [Double]?, _ error: Error?) -> Void
    ) {
        var urlComponents = URLComponents(string: "https://whitebit.com/api/v4/public/orderbook/\(paymentMethod)")!
        urlComponents.queryItems = [
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
                self?.logger.warning(Logger.Message(stringLiteral: "NO Data for whitebit: \(urlComponents.debugDescription)"))
                completion(nil, nil, nil)
                return
            }
            
            do {
                let orderbookData = try JSONDecoder().decode(OrderbookData.self, from: data)
                let asks = orderbookData.asks.compactMap { $0.first }.compactMap { Double($0) }
                let bids = orderbookData.bids.compactMap { $0.first }.compactMap { Double($0) }
                completion(asks, bids, nil)
            } catch (let decodingError) {
                self?.logger.warning(Logger.Message(stringLiteral: decodingError.localizedDescription))
                completion(nil, nil, decodingError)
            }
        }).resume()
    }
    
}

