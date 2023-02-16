//
//  BinanceDTOProvider.swift
//  
//
//  Created by Ruslan on 19.01.2023.
//

import Foundation
@testable import App

class BinanceDTOProvider {
    
    static func getSymbolsDTO() -> [BinanceAPIService.Symbol]? {
        
        do {
            let data = ExchangeInfoDTO.jsonString.data(using: .utf8)!
            let response = try JSONDecoder().decode(BinanceAPIService.ExchangeInfoResponse.self, from: data)
            return response.symbols
        } catch {
            return nil
        }
    }
    
}
