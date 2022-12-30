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
    
    let binanceTriangularUpdaterJob = TriangularsUpdaterJob(app: app, bot: TGBot.shared, stockEchange: .binance)
    app.queues.schedule(binanceTriangularUpdaterJob).hourly().at(1)
    
    let bybitTriangularUpdaterJob = TriangularsUpdaterJob(app: app, bot: TGBot.shared, stockEchange: .bybit)
    app.queues.schedule(bybitTriangularUpdaterJob).hourly().at(30)
    
    let huobiTriangularUpdaterJob = TriangularsUpdaterJob(app: app, bot: TGBot.shared, stockEchange: .huobi)
    app.queues.schedule(huobiTriangularUpdaterJob).hourly().at(50)
    
    try app.queues.startScheduledJobs()
    
    let defaultBotHandlers = DefaultBotHandlers(bot: TGBot.shared)
    defaultBotHandlers.addHandlers(app: app)
    
    try routes(app)
}
