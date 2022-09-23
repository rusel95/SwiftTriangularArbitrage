//
//  Opportunity.swift
//  
//
//  Created by Ruslan on 19.09.2022.
//

import Foundation

class TriangularOpportunity: CustomStringConvertible, Hashable {
    
    let contractsDescription: String
    let startDate: Date
    
    var latestUpdateDate: Date
    
    var updateMessageId: Int?
    var endDate: Date? = nil
    
    var surfaceResults: [SurfaceResult] = [] {
        didSet {
            latestUpdateDate = Date()
        }
    }
    
    init(
        contractsDescription: String,
        updateMessageId: Int? = nil,
        startDate: Date = Date()
    ) {
        self.contractsDescription = contractsDescription
        self.updateMessageId = updateMessageId
        self.startDate = startDate
        self.latestUpdateDate = startDate
    }
    
    static func == (lhs: TriangularOpportunity, rhs: TriangularOpportunity) -> Bool {
        return lhs.contractsDescription == rhs.contractsDescription
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(contractsDescription)
    }
    
    var currentProfitability: Double? {
        surfaceResults.last?.profitPercent
    }
    
    var averageProfitPercent: Double {
        surfaceResults.map { $0.profitPercent }.averageIncr()
    }
    
    var description: String {
        """
        \n\(contractsDescription)
        duration: \(Int(latestUpdateDate.timeIntervalSince(startDate))) seconds
        current profit percent: \(surfaceResults.last?.profitPercent.string() ?? "")
        average profit percent: \(averageProfitPercent.string())
        """
    }
    
}
