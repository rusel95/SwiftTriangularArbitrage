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
    
    // MARK: - STRUCTS

    struct Welcome: Codable {
        
        let code: String
        let message, messageDetail: String?
        let data: [Datum]
        let total: Int
        let success: Bool
        
    }

    struct Datum: Codable {
        
        let adv: Adv
        let advertiser: Advertiser
        
    }
    
    struct Advertiser: Codable {
        
        let userNo: String
        let realName: String?
        let nickName: String
        let margin, marginUnit, orderCount: String?
        let monthOrderCount: Int
        let monthFinishRate: Double
        let advConfirmTime: Int
        let email, registrationTime, mobile: String?
        let userType: String
        let tagIconUrls: [String]
        let userGrade: Int
        let userIdentity: String
        let proMerchant, isBlocked: String?
        
    }
    
    struct Adv: Codable {
        
        let advNo, classify, tradeType, asset: String
        let fiatUnit: String
        let advStatus, priceType, priceFloatingRatio, rateFloatingRatio: String?
        let currencyRate: String?
        let price, initAmount, surplusAmount: String
        let amountAfterEditing: String?
        let maxSingleTransAmount, minSingleTransAmount: String
        let buyerKycLimit, buyerRegDaysLimit, buyerBtcPositionLimit, remarks: String?
        let autoReplyMsg: String
        let payTimeLimit: Int
        let tradeMethods: [[String: String?]]
        let userTradeCountFilterTime, userBuyTradeCountMin, userBuyTradeCountMax, userSellTradeCountMin: String?
        let userSellTradeCountMax, userAllTradeCountMin, userAllTradeCountMax, userTradeCompleteRateFilterTime: String?
        let userTradeCompleteCountMin, userTradeCompleteRateMin, userTradeVolumeFilterTime, userTradeType: String?
        let userTradeVolumeMin, userTradeVolumeMax, userTradeVolumeAsset, createTime: String?
        let advUpdateTime, fiatVo, assetVo, advVisibleRet: String?
        let assetLogo: String?
        let assetScale, fiatScale, priceScale: Int
        let fiatSymbol: String
        let isTradable: Bool
        let dynamicMaxSingleTransAmount, minSingleTransQuantity, maxSingleTransQuantity, dynamicMaxSingleTransQuantity: String
        let tradableQuantity, commissionRate: String
        let tradeMethodCommissionRates: [String]
        let launchCountry: String?
        
    }
    
    struct BookTicker: Codable {
        
        let symbol: String
        let bidPrice: String
        let bidQty: String
        let askPrice: String
        let askQty: String
        
        var sellPrice: Double? {
            Double(bidPrice)
        }
        
        var buyPrice: Double? {
            Double(askPrice)
        }
        
    }
    
    // MARK: - PROPERTIES
    
    static let shared = BinanceAPIService()

    // MARK: - METHODS
    
    func getBookTicker(
        symbol: String,
        completion: @escaping(_ ticker: BookTicker?) -> Void
    ) {
        let session = URLSession.shared
        let url = URL(string: "https://api.binance.com/api/v3/ticker/bookTicker?symbol=\(symbol)")!
       
        var request = URLRequest(url: url)
        request.httpMethod = "Get"
        
        session.dataTask(with: request) {(data, response, error) in
            if let error = error {
                print("error is \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let data = data else { return }
            
            do {
                let ticker = try JSONDecoder().decode(BookTicker.self, from: data)
                completion(ticker)
            } catch {
                completion(nil)
            }
        }.resume()
    }
    
    // TODO: - should be separated into different methods which gives SELL/BUY separately
    func loadAdvertisements(
        paymentMethod: String,
        crypto: String,
        numberOfAdvsToConsider: UInt8 = 10,
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

