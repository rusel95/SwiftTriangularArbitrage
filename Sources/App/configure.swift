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
    
    for stockExchange in StockExchange.allCases.filter({ $0.isTurnedOn }) {
        let tickersUpdaterJob = TickersUpdaterJob(app: app, bot: TGBot.shared, stockEchange: stockExchange)
        app.queues.schedule(tickersUpdaterJob).everySecond()
    }
    
    for stockExchange in StockExchange.allCases {
        let triangularUpdaterJob = TriangularsUpdaterJob(app: app, bot: TGBot.shared, stockEchange: stockExchange)
        app.queues.schedule(triangularUpdaterJob).hourly().at(stockExchange.minuteToScheduleTriangularUpdater)
    }
    
    let tgUpdater = TGMessagesUpdaterJob(app: app, bot: TGBot.shared)
    app.queues.schedule(tgUpdater).everySecond()
    
    try app.queues.startScheduledJobs()
    
    try routes(app)
}
