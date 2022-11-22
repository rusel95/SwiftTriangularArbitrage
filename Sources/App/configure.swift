import Vapor
import telegram_vapor_bot
import Logging

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
    
    let defaultBotHandlers = DefaultBotHandlers(bot: TGBot.shared)
    defaultBotHandlers.addHandlers(app: app)
    
    try routes(app)
}
