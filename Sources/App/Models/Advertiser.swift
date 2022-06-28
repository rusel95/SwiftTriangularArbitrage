//
//  Advertiser.swift
//  
//
//  Created by Ruslan Popesku on 24.06.2022.
//

struct Advertiser: Codable {
    
    let userNo: String
    let realName: String?
    let nickName: String
    let margin, marginUnit, orderCount: String?
    let monthOrderCount: Int
    let monthFinishRate: Double
    let advConfirmTime: Int
    let email, registrationTime, mobile: String?
    let userType: String
    let tagIconUrls: [String]
    let userGrade: Int
    let userIdentity: String
    let proMerchant, isBlocked: String?
    
}
