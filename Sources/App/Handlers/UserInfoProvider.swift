//
//  UserInfoService.swift
//
//
//  Created by Ruslan Popesku on 14.07.2022.
//

import Foundation
import telegram_vapor_bot
import Vapor

final class UserInfoProvider: NSObject {
    
    // MARK: - PROPERTIES
    
    static let shared = UserInfoProvider()
    
    private var usersInfo: Set<UserInfo> = []

    // MARK: - METHODS
    
    func handleModeSelected(chatId: Int64, user: TGUser, mode: Mode) {
        if let userInfo = usersInfo.first(where: { $0.chatId == chatId }) {
            userInfo.selectedModes.insert(mode)
        } else {
            let newUserInfo = UserInfo(chatId: chatId, user: user, selectedModes: [mode])
            usersInfo.insert(newUserInfo)
        }
    }
    
    
    func getAllUsersInfo() -> Set<UserInfo> {
        return usersInfo
    }
    
}

