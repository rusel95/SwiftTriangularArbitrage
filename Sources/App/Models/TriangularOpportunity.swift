//
//  Opportunity.swift
//  
//
//  Created by Ruslan on 19.09.2022.
//

import Foundation

final class TriangularOpportunity: CustomStringConvertible, Hashable {
    
    enum AutoTradeCicle {
        case pending
        case firstTradeStarted
        case firstTradeFinished
        case firstTradeError(description: String)
        case secondTradeStarted
        case secondTradeFinished
        case secondTradeError(description: String)
        case thirdTradeStarted
        case thirdTradeFinished(result: String)
        case thirdTradeError(description: String)
    }
    
    let contractsDescription: String
    let startDate: Date
    let firstSurfaceResult: SurfaceResult
    
    var latestUpdateDate: Date
    
    var updateMessageId: Int?
    
    var autotradeCicle: AutoTradeCicle = .pending
    var autotradeLog: String = ""
    
    var surfaceResults: [SurfaceResult] {
        didSet {
            latestUpdateDate = Date()
        }
    }
    
    init(
        contractsDescription: String,
        firstSurfaceResult: SurfaceResult,
        updateMessageId: Int? = nil,
        startDate: Date = Date()
    ) {
        self.contractsDescription = contractsDescription
        self.firstSurfaceResult = firstSurfaceResult
        self.surfaceResults = [firstSurfaceResult]
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
    
    var duration: Int {
        Int(latestUpdateDate.timeIntervalSince(startDate))
    }
    
    var description: String {
        """
        \(surfaceResults.last?.shortDescription ?? "")\n
        start time: \(startDate.readableDescription)
        last update time: \(latestUpdateDate.readableDescription)
        duration: \(duration) seconds
        starting profit: \(surfaceResults.first?.profitPercent.string() ?? "")%
        average profit: \(averageProfitPercent.string())%
        highest profit: \(surfaceResults.sorted(by: { $0.profitPercent > $1.profitPercent }).first?.profitPercent.string() ?? "")%
        current profit: \(surfaceResults.last?.profitPercent.string() ?? "")%
        """
    }
    
    var tradingDescription: String {
        """
        \(description)\n
        \(autotradeLog)
        """
    }
    
}
