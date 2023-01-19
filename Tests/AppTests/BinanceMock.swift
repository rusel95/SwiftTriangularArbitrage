//
//  File.swift
//  
//
//  Created by Ruslan on 19.01.2023.
//

import Foundation

//
//  DraftListMock.swift
//  PlanolyTests
//
//  Created by Anderson Gralha on 13/01/23.
//  Copyright © 2023 Planogram, Inc. All rights reserved.
//

import Foundation
@testable import App

class BinanceMock {
    
    static func getMock() -> [BinanceAPIService.Symbol]? {
        let path = Bundle(for: BinanceMock.self).bundlePath.appending("/test.json")
        
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let decoder = JSONDecoder()
            let response = try decoder.decode(BinanceAPIService.ExchangeInfoResponse.self, from: data)
            return response.symbols
        } catch {
            return nil
        }
    }
}
