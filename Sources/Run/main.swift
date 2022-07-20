import App
import Vapor

var env = try Environment.detect()
// find out if this if this have to be selected
//try LoggingSystem.bootstrap(from: &env)
let app = Application(env)
defer {
    UsersInfoProvider.shared.syncStorage()
    Logging.shared.log(critical: "Bot Shutdown")
    app.shutdown()
}
try configure(app)
try app.run()
