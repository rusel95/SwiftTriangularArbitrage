//
//  SMTPCredentials.swift
//  
//
//  Created by Ruslan on 23.12.2022.
//

import Foundation

import VaporSMTPKit

extension SMTPCredentials {
    static var `default`: SMTPCredentials {
        return SMTPCredentials(
            hostname: "smtp-relay.sendinblue.com",
            ssl: .startTLS(configuration: .default),
            email: "ruslanpopesku95@gmail.com",
            password: String.readToken(from: "sendinblueAPIKey")
        )
    }
}
