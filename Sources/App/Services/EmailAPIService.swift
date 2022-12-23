//
//  EmailAPIService.swift
//  
//
//  Created by Ruslan on 21.12.2022.
//

import SMTPKitten
import Vapor

final class EmailAPIService {
    
    // MARK: - STRUCTS

    private let app: Application

    // MARK: - PROPERTIES
    
    init(app: Application) {
        self.app = app
    }
    
    // MARK: - METHODS
    
    func sendEmail(text: String) {
        let email = Mail(
            from: "ruslanpopesku95@gmail.com",
            to: [
                MailUser(name: "Myself", email: "ruslanpopesku95@gmail.com")
            ],
            subject: "Your new mail server!",
            contentType: .plain,
            text: text
        )
        app.sendMail(email, withCredentials: .default).whenComplete({ result in
            switch result {
            case .success(let description):
                print(description)
            case .failure(let error):
                print(error)
            }
        })
    }
    
}
