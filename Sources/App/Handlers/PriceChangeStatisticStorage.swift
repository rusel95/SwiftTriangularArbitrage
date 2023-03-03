//
//  PriceChangeStatisticStorage.swift
//  
//
//  Created by Ruslan Popesku on 02.03.2023.
//

final class PriceChangeStatisticStorage {
    
    static let shared: PriceChangeStatisticStorage = PriceChangeStatisticStorage()
    
    private var bookTickersDict: ThreadSafeDictionary<String, BookTicker> = ThreadSafeDictionary()
    
    private init() {}
    
    var tradingVolumeStableEquivalentDict: ThreadSafeDictionary<String, Double> = ThreadSafeDictionary(dict: [:])
    
    func setTradingVolumeStableEquivalent(
        priceChangeStatistics: [SymbolPriceChangeStatistic],
        bookTickers: [BookTicker],
        symbols: [BinanceAPIService.Symbol]
    ) {
        self.bookTickersDict = ThreadSafeDictionary(dict: bookTickers.toDictionary(with: { $0.symbol }))
        let symbolsDict = symbols.toDictionary(with: { $0.symbol })
        
        for symbolPriceChangeStatistic in priceChangeStatistics {
            guard let baseAsset = symbolsDict[symbolPriceChangeStatistic.symbol]?.baseAsset,
                  let volume = Double(symbolPriceChangeStatistic.volume),
                  let approximateStableEquivalent = try? getApproximateStableEquivalent(asset: baseAsset, assetQuantity: volume) else {
                continue
            }
            
            let approximateVolumeMultipler = approximateStableEquivalent / 24.0 / 60.0 / 60.0 / Constants.minimumQuantityStableEquivalent
            tradingVolumeStableEquivalentDict[symbolPriceChangeStatistic.symbol] = approximateVolumeMultipler
        }
    }
    
    private func getApproximateStableEquivalent(asset: String, assetQuantity: Double) throws -> Double {
        guard Constants.stablesSet.contains(asset) == false else { return assetQuantity }
        
        if let assetToStableSymbol = bookTickersDict["\(asset)USDT"], let assetToStableApproximatePrice = assetToStableSymbol.sellPrice {
            return assetQuantity * assetToStableApproximatePrice
        } else if let stableToAssetSymbol = bookTickersDict["USDT\(asset)"], let stableToAssetApproximatePrice = stableToAssetSymbol.buyPrice {
            return assetQuantity / stableToAssetApproximatePrice
        } else {
            throw CommonError.noMinimalPortion(description: "\nNo Approximate Minimal Portion for asset \(asset)")
        }
    }
    
}
