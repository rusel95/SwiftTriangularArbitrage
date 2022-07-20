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
    
    private let fileName = "usersInfo.txt"

    override init() {
        do {
            let fileURL: URL
            if let documentDirectory = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
                fileURL = documentDirectory.appendingPathComponent(fileName)
            } else {
                fileURL = URL(fileURLWithPath: "/root/p2pHelper/\(fileName)")
            }
            TGBot.log.info(Logger.Message(stringLiteral: fileURL.absoluteString))
            let jsonData = try Data(contentsOf: fileURL)
            self.usersInfo = try JSONDecoder().decode(Set<UserInfo>.self, from: jsonData)
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
        do {
            let fileURL: URL
            if let documentDirectory = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
                fileURL = documentDirectory.appendingPathComponent(fileName)
            } else {
                fileURL = URL(fileURLWithPath: "/root/p2pHelper/\(fileName)")
            }
            TGBot.log.info(Logger.Message(stringLiteral: fileURL.absoluteString))
            let endcodedData = try JSONEncoder().encode(usersInfo)
            try endcodedData.write(to: fileURL)
        } catch {
            TGBot.log.error(error.logMessage)
        }
    }
    
}

