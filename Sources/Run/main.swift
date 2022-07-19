import App
import Vapor

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)
let app = Application(env)
defer {
    UsersInfoProvider.shared.syncStorage()
    // Add some logs about crash with stacktrace
    app.shutdown()
}
try configure(app)
try app.run()
