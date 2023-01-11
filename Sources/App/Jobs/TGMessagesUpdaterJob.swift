//
//  File.swift
//  
//
//  Created by Ruslan on 11.01.2023.
//

import Queues
import Vapor
import telegram_vapor_bot
import CoreFoundation

struct UpdateMessage: Codable {
    let messageID: String
    let text: String
}

struct TGMessagesUpdaterJob: ScheduledJob {
    
    private let app: Application
    private let bot: TGBotPrtcl
    
    init(app: Application, bot: TGBotPrtcl) {
        self.app = app
        self.bot = bot
    }
    
    func run(context: Queues.QueueContext) -> NIOCore.EventLoopFuture<Void> {
        return context.eventLoop.performWithTask {
            guard Calendar.current.component(.second, from: Date()) % 2 == 0 else { return }
            
            do {
                var editParamsArray: [TGEditMessageTextParams] = try await app.caches.memory.get(
                    "editParamsArray",
                    as: [TGEditMessageTextParams].self
                ) ?? []
              
                if let firstScheduledMessageEditParams = editParamsArray.first {
                    _ = try bot.editMessageText(params: firstScheduledMessageEditParams)
                    print("\(editParamsArray.count)")
                    editParamsArray.removeFirst()
                    try await app.caches.memory.set("editParamsArray", to: editParamsArray)
                }
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
}

extension TGEditMessageTextParams: Decodable {
   
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let chatId = try? container.decode(TGChatId.self, forKey: .chatId)
        let messageId = try? container.decode(Int.self, forKey: .messageId)
        let text = try container.decode(String.self, forKey: .text)
        
        self.init(chatId: chatId, messageId: messageId, text: text)
    }
    
}
