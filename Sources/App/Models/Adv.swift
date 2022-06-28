//
//  Adv.swift
//  
//
//  Created by Ruslan Popesku on 24.06.2022.
//

struct Adv: Codable {
    
    let advNo, classify, tradeType, asset: String
    let fiatUnit: String
    let advStatus, priceType, priceFloatingRatio, rateFloatingRatio: String?
    let currencyRate: String?
    let price, initAmount, surplusAmount: String
    let amountAfterEditing: String?
    let maxSingleTransAmount, minSingleTransAmount: String
    let buyerKycLimit, buyerRegDaysLimit, buyerBtcPositionLimit, remarks: String?
    let autoReplyMsg: String
    let payTimeLimit: Int
    let tradeMethods: [[String: String?]]
    let userTradeCountFilterTime, userBuyTradeCountMin, userBuyTradeCountMax, userSellTradeCountMin: String?
    let userSellTradeCountMax, userAllTradeCountMin, userAllTradeCountMax, userTradeCompleteRateFilterTime: String?
    let userTradeCompleteCountMin, userTradeCompleteRateMin, userTradeVolumeFilterTime, userTradeType: String?
    let userTradeVolumeMin, userTradeVolumeMax, userTradeVolumeAsset, createTime: String?
    let advUpdateTime, fiatVo, assetVo, advVisibleRet: String?
    let assetLogo: String?
    let assetScale, fiatScale, priceScale: Int
    let fiatSymbol: String
    let isTradable: Bool
    let dynamicMaxSingleTransAmount, minSingleTransQuantity, maxSingleTransQuantity, dynamicMaxSingleTransQuantity: String
    let tradableQuantity, commissionRate: String
    let tradeMethodCommissionRates: [String]
    let launchCountry: String?
    
}
