import App
import Vapor

var env = try Environment.detect()
try LoggingSystem.bootstrap(from: &env)
let app = Application(env)
defer {
    // Do some external logging
    app.shutdown()
}
try configure(app)
try app.run()
