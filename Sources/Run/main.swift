import App
import Vapor
import Logging

var env = try Environment.detect()
// find out if this if this have to be selected
//try LoggingSystem.bootstrap(from: &env)
let app = Application(env)
defer {
    UsersInfoProvider.shared.syncStorage()
    Logger(label: "main.logger").critical(Logger.Message(stringLiteral:  "Bot Shutdown"))
    app.shutdown()
}
try configure(app)
try app.run()
