//
//  WalletTransactionsStreamFunnelType.swift
//  ledger-wallet-ios
//
//  Created by Nicolas Bigot on 16/12/2015.
//  Copyright © 2015 Ledger. All rights reserved.
//

import Foundation

protocol WalletTransactionsStreamFunnelType: class {
    
    func process(context: WalletTransactionsStreamContext, completion: (Bool) -> Void)
    func flush()
    
    init(storeProxy: WalletStoreProxy, addressCache: WalletAddressCache, layoutHolder: WalletLayoutHolder, callingQueue: NSOperationQueue)
    
}

extension WalletTransactionsStreamFunnelType {
    
    func process(context: WalletTransactionsStreamContext, completion: (Bool) -> Void)
    {
        completion(true)
    }
    
    func flush() {
        
    }
    
}