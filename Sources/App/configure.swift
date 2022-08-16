import Vapor
import telegram_vapor_bot
import Logging

public func configure(_ app: Application) throws {

    LoggingSystem.bootstrap { label in
        MultiplexLogHandler([
            StreamLogHandler.standardOutput(label: label)
        ])
    }
    
    let connection: TGConnectionPrtcl = TGLongPollingConnection()
    TGBot.configure(connection: connection, botId: String.readToken(from: "token"), vaporClient: app.client)
    try TGBot.shared.start()
    TGBot.log.logLevel = .error
    
    DefaultBotHandlers.shared.addHandlers(app: app, bot: TGBot.shared)
    
    try routes(app)
}
