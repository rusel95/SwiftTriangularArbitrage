//
//  BinanceAPIService.swift
//  
//
//  Created by Ruslan Popesku on 23.06.2022.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class BinanceAPIService {
    
    // MARK: - PROPERTIES
    
    static let shared = BinanceAPIService()

    // MARK: - METHODS
    
    func loadAdvertisements(
        paymentMethod: String,
        crypto: String,
        numberOfAdvsToConsider: UInt8,
        completion: @escaping(_ buyAdvs: [Adv]?, _ sellAdvs: [Adv]?, _ error: Error?) -> Void
    ) {
        var finalError: Error?
        var buyAdvs: [Adv]?
        var sellAdvs: [Adv]?
        
        let group = DispatchGroup()
        
        let session = URLSession.shared
        let url = URL(string: "https://p2p.binance.com/bapi/c2c/v2/friendly/c2c/adv/search")!
       
        var sellRequest = URLRequest(url: url)
        sellRequest.httpMethod = "POST"
        sellRequest.setValue("Application/json", forHTTPHeaderField: "Content-Type")
        sellRequest.setValue("p2p.binance.com", forHTTPHeaderField: "Host")
        sellRequest.setValue("https://p2p.binance.com", forHTTPHeaderField: "Origin")
        sellRequest.setValue("Trailers", forHTTPHeaderField: "TE")

        let parametersDictionary: [String : Any] = [
            "asset": crypto,
            "fiat": "UAH",
            "page": 1,
            "payTypes": [paymentMethod],
            "rows": numberOfAdvsToConsider,
//            "transAmount": "20000.00"
        ]
        
        var sellParametersDictionary = parametersDictionary
        sellParametersDictionary["tradeType"] = "SELL"
        sellRequest.httpBody = try? JSONSerialization.data(withJSONObject: sellParametersDictionary) as Data
        
        group.enter()
        session.dataTask(with: sellRequest) {(data, response, error) in
            if let error = error {
                print("error is \(error.localizedDescription)")
                finalError = error
                group.leave()
                return
            }
            
            guard let data = data else { return }
            
            do {
                let welcome = try JSONDecoder().decode(Welcome.self, from: data) //Creates a User Object if your JSON data matches the structure of your class
                sellAdvs = welcome.data.compactMap { $0.adv }
                
//                let all = welcome.data
//                    .map { $0.advertiser.nickName }
//
//                print("All: \(all)")
//
//                let amountFilter = welcome.data
//                    .filter { Double($0.adv.surplusAmount) ?? 0 >= 200 }
//                    .map { $0.advertiser.nickName }
//
//                print("Amount Filter: \(amountFilter)")
//
//                let singleFilter = welcome.data
//                    .filter { Double($0.adv.surplusAmount) ?? 0 >= 200 }
//                    .filter { Double($0.adv.minSingleTransAmount) ?? 0 >= 2000 && Double($0.adv.minSingleTransAmount) ?? 0 <= 50000 }
//                    .map { $0.advertiser.nickName }
//
//                print("Single Filter: \(singleFilter)")
                
                group.leave()
            } catch (let decodingError) {
                finalError = decodingError
                group.leave()
            }
        }.resume()
        
        var buyParametersDictionary = parametersDictionary
        buyParametersDictionary["tradeType"] = "BUY"
        
        var buyRequest = sellRequest
        buyRequest.httpBody = try? JSONSerialization.data(withJSONObject: buyParametersDictionary) as Data
        
        group.enter()
        session.dataTask(with: buyRequest) {(data, response, error) in
            if let error = error {
                print("error is \(error.localizedDescription)")
                finalError = error
                group.leave()
                return
            }
            
            guard let data = data else { return }
            
            do {
                let welcome = try JSONDecoder().decode(Welcome.self, from: data)
                buyAdvs = welcome.data.compactMap { $0.adv }
                group.leave()
            } catch (let decodingError) {
                finalError = decodingError
                group.leave()
            }
        }.resume()
        
        group.notify(queue: .global()) {
            completion(buyAdvs, sellAdvs, finalError)
        }
    }
    
}

