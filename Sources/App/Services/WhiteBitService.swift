//
//  WhiteBitService.swift
//  
//
//  Created by Ruslan Popesku on 27.06.2022.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class WhiteBitService {
    
    enum Asset: String {
        case usdtuah = "USDT_UAH"
    }
    
    struct OrderbookData: Codable {
        
        let timestamp: Int
        let asks: [[String]]
        let bids: [[String]]
        
    }
    
    // MARK: - PROPERTIES
    
    static let shared = WhiteBitService()

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

