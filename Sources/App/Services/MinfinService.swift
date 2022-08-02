//
//  MinfinService.swift
//
//
//  Created by Ruslan Popesku on 02.08.2022.
//


import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Logging
import Jobs

final class MinfinService {
    
    // MARK: - Structs
    
    struct Auction {
        let type: AuctionType
        let info: AuctionInfo
    }
    
    enum AuctionType: String, CaseIterable {
       
        case usd
        case eur
        
        var description: String {
            "Обмiнники"
        }
        
    }
    
    struct AuctionInfo: Codable {
        let time, ask, bid: String
        let askCount, bidCount, askSum, bidSum: Int
    }
    
    // MARK: - PROPERTIES
    
    static let shared = MinfinService()
    
    private(set) var auctions: [Auction]? = nil
    
    private var logger = Logger(label: "api.minfin")
    
    private lazy var token: String = {
        .readToken(from: "minfinToken")
    }()
    
    private init() {
        Jobs.add(interval: Duration.hours(1)) { [weak self] in
            self?.getAuctions(completion: { [weak self] auctions in
                self?.auctions = auctions
            })
        }
    }
    
    // MARK: - METHODS
    
    private func getAuctions(completion: @escaping([Auction]?) -> Void) {
        let url = URL(string: "https://api.minfin.com.ua/auction/info/\(token)/")!
        URLSession.shared.dataTask(with: url, completionHandler: { [weak self] data, response, error in
            if let error = error {
                self?.logger.warning(Logger.Message(stringLiteral: error.localizedDescription))
                completion(nil)
                return
            }
            
            guard let data = data else {
                self?.logger.warning(Logger.Message(stringLiteral: "NO Data for Minfin \(url.debugDescription)"))
                completion (nil)
                return
            }
            
            do {
                let rawAuctions = try JSONDecoder().decode([String: AuctionInfo].self, from: data)
                
                var auctions: [Auction] = []
                rawAuctions.forEach({ rawAuction in
                    guard let auctionType = AuctionType(rawValue: rawAuction.key) else { return }
                    
                    auctions.append(Auction(type: auctionType, info: rawAuction.value))
                })
                  
                completion(auctions)
            } catch (let decodingError) {
                self?.logger.error(Logger.Message(stringLiteral: decodingError.localizedDescription))
                completion(nil)
            }
        }).resume()
    }
    
}

