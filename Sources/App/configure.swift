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
    
    let binanceTickersUpdaterJob = TickersUpdaterJob(app: app, bot: TGBot.shared, stockEchange: .binance)
    app.queues.schedule(binanceTickersUpdaterJob).everySecond()

    let bybitTickersUpdaterJob = TickersUpdaterJob(app: app, bot: TGBot.shared, stockEchange: .bybit)
    app.queues.schedule(bybitTickersUpdaterJob).everySecond()

    let huobiTickersUpdaterJob = TickersUpdaterJob(app: app, bot: TGBot.shared, stockEchange: .huobi)
    app.queues.schedule(huobiTickersUpdaterJob).everySecond()

    let exmoTickersUpdaterJob = TickersUpdaterJob(app: app, bot: TGBot.shared, stockEchange: .exmo)
    app.queues.schedule(exmoTickersUpdaterJob).everySecond()
    
    let kucoinTickersUpdaterJob = TickersUpdaterJob(app: app, bot: TGBot.shared, stockEchange: .kucoin)
    app.queues.schedule(kucoinTickersUpdaterJob).everySecond()
    
    let krakenTickersUpdaterJob = TickersUpdaterJob(app: app, bot: TGBot.shared, stockEchange: .kraken)
    app.queues.schedule(krakenTickersUpdaterJob).everySecond()
    
    let binanceTriangularUpdaterJob = TriangularsUpdaterJob(app: app, bot: TGBot.shared, stockEchange: .binance)
    app.queues.schedule(binanceTriangularUpdaterJob).hourly().at(50)
    
    let bybitTriangularUpdaterJob = TriangularsUpdaterJob(app: app, bot: TGBot.shared, stockEchange: .bybit)
    app.queues.schedule(bybitTriangularUpdaterJob).hourly().at(10)
    
    let huobiTriangularUpdaterJob = TriangularsUpdaterJob(app: app, bot: TGBot.shared, stockEchange: .huobi)
    app.queues.schedule(huobiTriangularUpdaterJob).hourly().at(30)
    
    let exmoTriangularUpdaterJob = TriangularsUpdaterJob(app: app, bot: TGBot.shared, stockEchange: .exmo)
    app.queues.schedule(exmoTriangularUpdaterJob).hourly().at(45)
    
    let kucoinTriangularUpdaterJob = TriangularsUpdaterJob(app: app, bot: TGBot.shared, stockEchange: .kucoin)
    app.queues.schedule(kucoinTriangularUpdaterJob).hourly().at(0)
    
    let krakenTriangularUpdaterJob = TriangularsUpdaterJob(app: app, bot: TGBot.shared, stockEchange: .kraken)
    app.queues.schedule(krakenTriangularUpdaterJob).hourly().at(27)
    
    let tgUpdater = TGMessagesUpdaterJob(app: app, bot: TGBot.shared)
    app.queues.schedule(tgUpdater).everySecond()
    
    try app.queues.startScheduledJobs()
    
    let defaultBotHandlers = DefaultBotHandlers(bot: TGBot.shared)
    defaultBotHandlers.addHandlers(app: app)
    
    try routes(app)
}
