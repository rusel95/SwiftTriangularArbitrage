//
//  TriangularOpportunity.swift
//  
//
//  Created by Ruslan on 19.09.2022.
//

import Foundation

final class TriangularOpportunity: Codable, CustomStringConvertible, Hashable {
    
    enum AutoTradeCicle: Codable, Equatable {
        case pending
        case depthCheck
        case readyToTrade
        case trading
        case completed
        case forbidden
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
        lhs.contractsDescription == rhs.contractsDescription
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
    
    var duration: Double {
        latestUpdateDate.timeIntervalSince(startDate)
    }
    
    var description: String {
        """
        \(surfaceResults.last?.shortDescription ?? "")\n
        start time: \(startDate.readableDescription)
        last update time: \(latestUpdateDate.readableDescription)
        duration: \(duration.string(maxFractionDigits: 4)) seconds
        starting profit: \(surfaceResults.first?.profitPercent.string(maxFractionDigits: 2) ?? "")%
        average profit: \(averageProfitPercent.string(maxFractionDigits: 2))%
        highest profit: \(surfaceResults.sorted(by: { $0.profitPercent > $1.profitPercent }).first?.profitPercent.string(maxFractionDigits: 2) ?? "")%
        current profit: \(surfaceResults.last?.profitPercent.string(maxFractionDigits: 2) ?? "")%
        """
    }
    
    var tradingDescription: String {
        """
        \(description)
        \(autotradeLog)
        """
    }
    
}
