//
//  PriceStatisticUpdaterJob.swift
//  
//
//  Created by Ruslan Popesku on 02.03.2023.
//

import Queues
import Vapor
import CoreFoundation

struct PriceStatisticUpdaterJob: ScheduledJob {
    
    private let app: Application
    private let emailService: EmailService
    
    init(app: Application) {
        self.app = app
        self.emailService = EmailService(app: app)
    }
    
    func run(context: Queues.QueueContext) -> NIOCore.EventLoopFuture<Void> {
        return context.eventLoop.performWithTask {
            do {
                let priceChangeStatisticElements = try await BinanceAPIService.shared.getPriceChangeStatistics()
                let bookTickers = try await BinanceAPIService.shared.getAllBookTickers()
                let symbols = try await BinanceAPIService.shared.getExchangeInfo()
                
                PriceChangeStatisticStorage.shared.setTradingVolumeStableEquivalent(
                    priceChangeStatistics: priceChangeStatisticElements,
                    bookTickers: bookTickers,
                    symbols: symbols
                )
            } catch {
                print(error.localizedDescription)
                emailService.sendEmail(
                    subject: "[price statistic]",
                    text: error.localizedDescription
                )
            }
        }
    }
    
}
