//
//  UserInfo.swift
//  
//
//  Created by Ruslan Popesku on 18.07.2022.
//

import telegram_vapor_bot

final class UserInfo: Hashable, Equatable {

    let chatId: Int64
    let id: Int64
    let firstName: String?
    let lastName: String?
    let username: String?
    
    var selectedModes: Set<Mode> = []
    
    init(chatId: Int64,
         user: TGUser,
         selectedModes: Set<Mode>) {
        self.chatId = chatId
        self.id = user.id
        self.firstName = user.firstName
        self.lastName = user.lastName
        self.username = user.username
        self.selectedModes = selectedModes
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.chatId)
        hasher.combine(self.id)
        hasher.combine(self.selectedModes)
    }

    static func == (lhs: UserInfo, rhs: UserInfo) -> Bool {
        lhs.chatId == rhs.chatId
    }
    
}
