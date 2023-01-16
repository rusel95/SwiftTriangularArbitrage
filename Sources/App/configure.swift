import Vapor
import telegram_vapor_bot
import Logging
import QueuesRedisDriver

public func configure(_ app: Application) throws {
    
    app.http.server.configuration.port = 8080
    LoggingSystem.bootstrap { label in
        MultiplexLogHandler([
            StreamLogHandler.standardOutput(label: label)
        ])
    }
    let connection: TGConnectionPrtcl = TGLongPollingConnection()
    TGBot.configure(connection: connection, botId: String.readToken(from: "token"), vaporClient: app.client)
    try TGBot.shared.start()
    TGBot.log.logLevel = .error
    
    try app.queues.use(.redis(url: "redis://127.0.0.1:6379"))
    
    let defaultBotHandlers = DefaultBotHandlers(bot: TGBot.shared)
    defaultBotHandlers.addHandlers(app: app)
    
    for stockExchange in StockExchange.allCases {
        let tickersUpdaterJob = TickersUpdaterJob(app: app, bot: TGBot.shared, stockEchange: stockExchange)
        app.queues.schedule(tickersUpdaterJob).everySecond()
    }
    
    let binanceTriangularUpdaterJob = TriangularsUpdaterJob(app: app, bot: TGBot.shared, stockEchange: .binance)
    app.queues.schedule(binanceTriangularUpdaterJob).hourly().at(0)
    
    let bybitTriangularUpdaterJob = TriangularsUpdaterJob(app: app, bot: TGBot.shared, stockEchange: .bybit)
    app.queues.schedule(bybitTriangularUpdaterJob).hourly().at(10)
    
    let huobiTriangularUpdaterJob = TriangularsUpdaterJob(app: app, bot: TGBot.shared, stockEchange: .huobi)
    app.queues.schedule(huobiTriangularUpdaterJob).hourly().at(15)
    
    let exmoTriangularUpdaterJob = TriangularsUpdaterJob(app: app, bot: TGBot.shared, stockEchange: .exmo)
    app.queues.schedule(exmoTriangularUpdaterJob).hourly().at(25)
    
    let kucoinTriangularUpdaterJob = TriangularsUpdaterJob(app: app, bot: TGBot.shared, stockEchange: .kucoin)
    app.queues.schedule(kucoinTriangularUpdaterJob).hourly().at(30)
    
    let krakenTriangularUpdaterJob = TriangularsUpdaterJob(app: app, bot: TGBot.shared, stockEchange: .kraken)
    app.queues.schedule(krakenTriangularUpdaterJob).hourly().at(40)
    
    let whitebitTriangularUpdaterJob = TriangularsUpdaterJob(app: app, bot: TGBot.shared, stockEchange: .whitebit)
    app.queues.schedule(whitebitTriangularUpdaterJob).hourly().at(50)
    
    let tgUpdater = TGMessagesUpdaterJob(app: app, bot: TGBot.shared)
    app.queues.schedule(tgUpdater).everySecond()
    
    try app.queues.startScheduledJobs()
    
    try routes(app)
}
