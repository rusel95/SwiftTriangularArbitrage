//
//  UserInfoService.swift
//
//
//  Created by Ruslan Popesku on 14.07.2022.
//

import telegram_vapor_bot
import Vapor

final class UsersInfoProvider: NSObject {
    
    // MARK: - PROPERTIES
    
    static let shared = UsersInfoProvider()
    
    private var usersInfo: Set<UserInfo> = []

    // MARK: - METHODS
    
    func getUsersInfo(selectedMode: Mode) -> Set<UserInfo> {
        usersInfo.filter { $0.selectedModes.contains(selectedMode) }
    }
    
    func handleModeSelected(chatId: Int64, user: TGUser, mode: Mode, onlineUpdatesMessageId: Int? = nil) {
        if let userInfo = usersInfo.first(where: { $0.chatId == chatId }) {
            userInfo.selectedModes.insert(mode)
        } else {
            let newUserInfo = UserInfo(chatId: chatId,
                                       user: user,
                                       selectedModes: [mode],
                                       onlineUpdatesMessageId: onlineUpdatesMessageId)
            usersInfo.insert(newUserInfo)
        }
    }
    
    func handleStopModes(chatId: Int64) {
        if let userInfo = usersInfo.first(where: { $0.chatId == chatId }) {
            userInfo.selectedModes.removeAll()
        }
    }
    
    func getAllUsersInfo() -> Set<UserInfo> {
        return usersInfo
    }
    
}

