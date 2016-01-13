//
//  WalletStoreBlockTask.swift
//  ledger-wallet-ios
//
//  Created by Nicolas Bigot on 12/01/2016.
//  Copyright © 2016 Ledger. All rights reserved.
//

import Foundation

struct WalletStoreBlockTask: WalletTaskType {

    private let block: WalletBlockContainer
    
    func process(completionQueue: NSOperationQueue, completion: () -> Void) {
        completion()
    }
    
    // MARK: Initialization
    
    init(block: WalletBlockContainer) {
        self.block = block
    }
    
}