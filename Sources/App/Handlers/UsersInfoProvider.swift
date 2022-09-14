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
    private var logger = Logger(label: "handlers.logger")
    
    private var storageURL: URL {
#if os(OSX)
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory.appendingPathComponent("usersInfo")
#else
        return URL(fileURLWithPath: "\(FileManager.default.currentDirectoryPath)/usersInfo")
#endif
    }

    // MARK: - INIT
    
    override init() {
        super.init()
        do {
            let jsonData = try Data(contentsOf: storageURL)
            self.usersInfo = try JSONDecoder().decode(Set<UserInfo>.self, from: jsonData)
        } catch {
            logger.critical(Logger.Message(stringLiteral: error.localizedDescription))
        }
    }
    
    // MARK: - METHODS
    
    func getAllUsersInfo() -> Set<UserInfo> {
        usersInfo
    }
    
    func getUsersInfo(selectedMode: BotMode) -> Set<UserInfo> {
        usersInfo.filter { $0.selectedModes.contains(selectedMode) }
    }
    
    func handleModeSelected(
        chatId: Int64,
        user: TGUser,
        mode: BotMode,
        onlineUpdatesMessageId: Int? = nil,
        arbitragingMessageId: Int? = nil,
        standartTriangularArbitragingMessageId: Int? = nil,
        stableTriangularArbitragingMessageId: Int? = nil
    ) {
        if let userInfo = usersInfo.first(where: { $0.chatId == chatId }) {
            userInfo.selectedModes.insert(mode)
            if standartTriangularArbitragingMessageId != nil {
                userInfo.standartTriangularArbitragingMessageId = standartTriangularArbitragingMessageId
            }
            if stableTriangularArbitragingMessageId != nil {
                userInfo.stableTriangularArbitragingMessageId = stableTriangularArbitragingMessageId
            }
        } else {
            let newUserInfo = UserInfo(
                chatId: chatId,
                user: user,
                selectedModes: [mode],
                triangularArbitragingMessageId: standartTriangularArbitragingMessageId,
                stableTriangularArbitragingMessageId: stableTriangularArbitragingMessageId
            )
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
            let endcodedData = try JSONEncoder().encode(usersInfo)
            try endcodedData.write(to: storageURL)
        } catch {
            logger.critical(Logger.Message(stringLiteral: error.localizedDescription))
        }
    }
    
}

