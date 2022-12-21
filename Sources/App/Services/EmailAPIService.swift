//
//  File.swift
//  
//
//  Created by Ruslan on 21.12.2022.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class EmailAPIService {
    
    // MARK: - STRUCTS
    
    struct EmailData: Codable {
        let personalizations: [Personalization]
        let from: From
        let subject: String
        let content: [Content]
    }

    struct Content: Codable {
        let type, value: String
    }

    struct From: Codable {
        let email: String
    }

    struct Personalization: Codable {
        let to: [From]
    }
    
    struct Response: Codable {
        let errors: [Error]?
    }

    struct Error: Codable {
        let message: String
        let field, help: String?
    }

    // MARK: - PROPERTIES
    
    static let shared = EmailAPIService()
    
    private lazy var apiKeyString: String = {
        String.readToken(from: "sendgridApiKey")
    }()
    
    private init() {}
    
    // MARK: - METHODS
    
    func sendEmail(with emailData: EmailData) async throws {
        var request = URLRequest(url: URL(string: "https://api.sendgrid.com/v3/mail/send")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKeyString)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(emailData)
        
        let (_, _) = try await URLSession.shared.asyncData(from: request)
    }
    
}
