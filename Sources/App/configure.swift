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
    
    let recipientJob = TriangularsUpdaterJob(bot: TGBot.shared)
    app.queues.schedule(recipientJob).hourly().at(0)
    
    try app.queues.startScheduledJobs()
    
    let defaultBotHandlers = DefaultBotHandlers(bot: TGBot.shared, app: app)
    defaultBotHandlers.addHandlers(app: app)
    
    try routes(app)
}
