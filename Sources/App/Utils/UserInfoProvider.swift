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
    
    // MARK: - TYPEALIAS

    typealias UserInfo = (chatId: Int64, user: TGUser)

    // MARK: - PROPERTIES
    
    static let shared = UserInfoProvider()

    // MARK: - METHODS
    
    func getUser(chatId: Int64) -> TGUser? {
        guard let data = UserDefaults.standard.data(forKey: String(chatId)) else {
            TGBot.log.critical(Logger.Message(stringLiteral: "No data for key"))
            return nil }
        
        return try? JSONDecoder().decode(TGUser.self, from: data)
    }
    
    func set(user: TGUser, chatId: Int64) {
        guard let encoded = try? JSONEncoder().encode(user) else { return }
        
        UserDefaults.standard.set(encoded, forKey: String(chatId))
    }
    
    func getAllUsersInfo() -> [UserInfo] {
        return UserDefaults.standard
            .dictionaryRepresentation()
            .compactMap { (key, value) in
                guard let chatId = Int64(key), let user = getUser(chatId: chatId) else { return nil }
                
                return UserInfo(chatId: chatId, user: user)
            }
    }
    
}

