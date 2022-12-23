//
//  EmailAPIService.swift
//  
//
//  Created by Ruslan on 21.12.2022.
//

import SMTPKitten
import Vapor

final class EmailAPIService {

    // MARK: - PROPERTIES
    
    private let app: Application
    
    private lazy var environmentDescription: String = {
#if DEBUG
        return "[Debug]"
#else
        return ""
#endif
    }()
    
    // MARK: - Init
    init(app: Application) {
        self.app = app
#if DEBUG
#else
        sendEmail(subject: "restart", text: "server restarted at \(Date().fullDateReadableDescription)")
#endif
        
    }
    
    // MARK: - METHODS
    
    func sendEmail(subject: String, text: String) {
        let email = Mail(
            from: "ruslanpopesku95@gmail.com",
            to: [
                MailUser(name: "Myself", email: "ruslanpopesku95@gmail.com")
            ],
            subject: "\(environmentDescription)\(subject)",
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
