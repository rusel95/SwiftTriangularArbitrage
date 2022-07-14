//
//  UserInfoService.swift
//  
//
//  Created by Ruslan Popesku on 14.07.2022.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import telegram_vapor_bot

final class UserInfoService {
    
    // MARK: - TYPEALIAS

    typealias UserInfo = (chatId: Int64, user: TGUser)

    // MARK: - PROPERTIES
    
    static let shared = UserInfoService()
    
    private let defaults = UserDefaults.standard

    // MARK: - METHODS
    
    func getUser(chatId: Int64) -> TGUser? {
        guard let data = defaults.value(forKey: String(chatId)) as? Data else { return nil }
        
        return try? JSONDecoder().decode(TGUser.self, from: data)
    }
    
    func set(user: TGUser, chatId: Int64) {
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: String(chatId))
        }
    }
    
    func getAllUsersInfo() -> [UserInfo] {
        return defaults
            .dictionaryRepresentation()
            .compactMap { (key, value) in
                guard let chatId = Int64(key), let user = getUser(chatId: chatId) else { return nil }
                
                return UserInfo(chatId: chatId, user: user)
            }
    }
    
}

