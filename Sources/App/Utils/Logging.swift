//
//  Logging.swift
//  
//
//  Created by Ruslan Popesku on 20.07.2022.
//

import Foundation
import Logging
import telegram_vapor_bot

public final class Logging {
    
    public static let shared = Logging()
    
    private var logger = Logger(label: "main.logger")
    
    public func log(info text: String) {
        logger.info(Logger.Message(stringLiteral: text))
    }
    
    public func log(error: Error) {
        logger.error(Logger.Message(stringLiteral: error.localizedDescription))
        TGBot.log.error(error.logMessage)
    }
    
    public func log(critical text: String) {
        logger.critical(Logger.Message(stringLiteral: text))
    }
    
}
