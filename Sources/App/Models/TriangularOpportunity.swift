//
//  Opportunity.swift
//  
//
//  Created by Ruslan on 19.09.2022.
//

import Foundation

struct TriangularOpportunity: Hashable {
    
    let contractsDescription: String
    let updateMessageId: Int
    let startDate: Date
    
    var surfaceResults: Set<SurfaceResult>
    
    var averageProfitPercent: Double {
        surfaceResults.map { $0.profitPercent }.averageIncr()
    }
    
}
