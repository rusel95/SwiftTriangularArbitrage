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
    
    private let fileName = "usersInfo.txt"

    override init() {
        do {
            guard let data = UserDefaults.standard.data(forKey: "usersInfo") else { return }
            
            let usersInfo = try JSONDecoder().decode(Set<UserInfo>.self, from: data)
            self.usersInfo = usersInfo
        } catch {
            print(error)
        }
    }
    
    // MARK: - METHODS
    
    func getUsersInfo(selectedMode: Mode) -> Set<UserInfo> {
        usersInfo.filter { $0.selectedModes.contains(selectedMode) }
    }
    
    func handleModeSelected(chatId: Int64, user: TGUser, mode: Mode, onlineUpdatesMessageId: Int? = nil) {
        if let userInfo = usersInfo.first(where: { $0.chatId == chatId }) {
            userInfo.selectedModes.insert(mode)
            if onlineUpdatesMessageId != nil {
                userInfo.onlineUpdatesMessageId = onlineUpdatesMessageId
            }
        } else {
            let newUserInfo = UserInfo(chatId: chatId,
                                       user: user,
                                       selectedModes: [mode],
                                       onlineUpdatesMessageId: onlineUpdatesMessageId)
            usersInfo.insert(newUserInfo)
        }
        update()
    }
    
    func handleStopModes(chatId: Int64) {
        if let userInfo = usersInfo.first(where: { $0.chatId == chatId }) {
            userInfo.selectedModes.removeAll()
        }
        update()
    }
    
    func getAllUsersInfo() -> Set<UserInfo> {
        return usersInfo
    }
    
    func update() {
        let res = try? JSONEncoder().encode(usersInfo)
        UserDefaults.standard.set(res, forKey: "usersInfo")
    }
    
}

