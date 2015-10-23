//
//  RemoteNotificationsRESTClient.swift
//  ledger-wallet-ios
//
//  Created by Nicolas Bigot on 12/02/2015.
//  Copyright (c) 2015 Ledger. All rights reserved.
//

import Foundation

final class RemoteNotificationsRESTClient: LedgerAPIRESTClient {
    
    // MARK: - Push token management
    
    func registerDeviceToken(token: NSData, toPairingId pairingId: String, completion: ((Bool) -> Void)?) {
        guard let tokenBase16String = BTCHexFromData(token) else {
            completion?(false)
            return
        }
        
        post("/2fa/pairings/\(pairingId)/push_token", parameters: ["push_token": tokenBase16String], encoding: .JSON) { data, request, response, error in
            completion?(error == nil && response != nil)
        }
    }
    
    func unregisterDeviceTokenFromPairingId(pairingId: String, completion: ((Bool) -> Void)?) {
        delete("/2fa/pairings/\(pairingId)/push_token") { data, request, response, error in
            completion?(error == nil && response != nil)
        }
    }
    
}