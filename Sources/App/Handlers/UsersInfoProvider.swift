//
//  UserInfoService.swift
//
//
//  Created by Ruslan Popesku on 14.07.2022.
//

import telegram_vapor_bot
import Vapor

public final class UsersInfoProvider: NSObject {
    
    // MARK: - PROPERTIES
    
    public static let shared = UsersInfoProvider()
    
    private var usersInfo: Set<UserInfo> = []
    
    private let userDefaultsKey = "usersInfo"

    override init() {
        do {
            guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
                TGBot.log.info(Logger.Message(stringLiteral: "No data for users"))
                return }
            
            let usersInfo = try JSONDecoder().decode(Set<UserInfo>.self, from: data)
            self.usersInfo = usersInfo
        } catch {
            TGBot.log.error(error.logMessage)
        }
    }
    
    // MARK: - METHODS
    
    func getAllUsersInfo() -> Set<UserInfo> {
        usersInfo
    }
    
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
        syncStorage()
    }
    
    func handleStopAllModes(chatId: Int64) {
        if let userInfo = usersInfo.first(where: { $0.chatId == chatId }) {
            userInfo.selectedModes.removeAll()
            syncStorage()
        }
    }
    
    public func syncStorage() {
        let endcodedData = try? JSONEncoder().encode(usersInfo)
        UserDefaults.standard.set(endcodedData, forKey: userDefaultsKey)
    }
    
}

