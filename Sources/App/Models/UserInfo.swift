//
//  UserInfo.swift
//  
//
//  Created by Ruslan Popesku on 18.07.2022.
//

import Foundation
import telegram_vapor_bot

final class UserInfo: Codable, Hashable, Equatable {

    let chatId: Int64
    let userId: Int64
    let firstName: String
    let lastName: String?
    let username: String?
    let languageCode: String?
    
    var selectedModes: Set<BotMode> = []
    
    var standartTriangularArbitragingMessageId: Int?
    var stableTriangularArbitragingMessageId: Int?
    var lastUsedDate: Date?
    
    init(
        chatId: Int64,
        user: TGUser,
        selectedModes: Set<BotMode>,
        triangularArbitragingMessageId: Int? = nil,
        stableTriangularArbitragingMessageId: Int? = nil
    ) {
        self.chatId = chatId
        self.userId = user.id
        self.firstName = user.firstName
        self.lastName = user.lastName
        self.username = user.username
        self.languageCode = user.languageCode
        self.selectedModes = selectedModes
        self.lastUsedDate = Date()
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.chatId)
    }

    static func == (lhs: UserInfo, rhs: UserInfo) -> Bool {
        lhs.chatId == rhs.chatId
    }
    
}

extension UserInfo: CustomStringConvertible {
    
    var description: String {
        "\(firstName) - modes: [\(selectedModes.map { $0.command }.joined(separator: ", "))] id: \(userId) last used: \(lastUsedDate?.fullDateReadableDescription ?? "")"
    }
    
}
