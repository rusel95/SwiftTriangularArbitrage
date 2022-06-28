//
//  File.swift
//  
//
//  Created by Ruslan Popesku on 23.06.2022.
//

import Foundation

// MARK: - Welcome
struct Welcome: Codable {
    
    let code: String
    let message, messageDetail: String?
    let data: [Datum]
    let total: Int
    let success: Bool
    
}

// MARK: - Datum
struct Datum: Codable {
    
    let adv: Adv
    let advertiser: Advertiser
    
}
