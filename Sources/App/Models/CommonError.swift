//
//  File.swift
//  
//
//  Created by Ruslan on 17.01.2023.
//

import Foundation

enum CommonError: Error, LocalizedError {
    case noMinimalPortion(description: String)
    case customError(description: String)
    
    var errorDescription: String? {
        switch self {
        case .customError(let description), .noMinimalPortion(let description):
            return description
        }
    }
}
