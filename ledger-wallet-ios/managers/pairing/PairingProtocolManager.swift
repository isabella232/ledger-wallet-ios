//
//  PairingProtocolManager.swift
//  ledger-wallet-ios
//
//  Created by Nicolas Bigot on 27/01/2015.
//  Copyright (c) 2015 Ledger. All rights reserved.
//

import Foundation

protocol PairingProtocolManagerDelegate: class {
    
    func pairingProtocolManager(pairingProtocolManager: PairingProtocolManager, didReceiveChallenge challenge: String)
    func pairingProtocolManager(pairingProtocolManager: PairingProtocolManager, didTerminateWithOutcome outcome: PairingProtocolManager.PairingOutcome)
    
}

class PairingProtocolManager: BasePairingManager {
    
    enum PairingOutcome {
        case DongleSucceeded
        case DongleFailed
        case DongleTerminated
        case DeviceSucceeded
        case DeviceFailed
        case DeviceTerminated
        case ServerDisconnected
    }

    weak var delegate: PairingProtocolManagerDelegate? = nil
    var webSocketBaseURL: String! = nil
    var context: PairingProtocolContext! = nil
    
    private var cryptor: PairingProtocolCryptor! = nil
    private var webSocket: WebSocket! = nil

    // MARK: - Pairing management
    
    func joinRoom(pairingId: String) {
        if (webSocket != nil) {
            return
        }
        
        // create websocket
        if (webSocketBaseURL == nil) { webSocketBaseURL = LedgerWebSocketBaseURL }
        webSocket = WebSocket(url: NSURL(string: webSocketBaseURL)!.URLByAppendingPathComponent("/2fa/channels"))
        webSocket.delegate = self
        webSocket.connect()

        // create context
        if (context == nil) { context = PairingProtocolContext() }
        
        // create cryptor 
        if (cryptor == nil) { cryptor = PairingProtocolCryptor() }
        
        // compute session key
        context.sessionKey = cryptor.sessionKeyForKeys(internalKey: context.internalKey, attestationKey: context.attestationKey)
        
        // send join message
        context.pairingId = pairingId
        let message = messageWithType(MessageType.Join, data: ["room": pairingId])
        sendMessage(message, webSocket: webSocket)
    }
    
    func sendPublicKey() {
        if (webSocket == nil) {
            return
        }
        
        // send public key
        let message = messageWithType(MessageType.Identify, data: ["public_key": Crypto.Encode.base16StringFromData(context.internalKey.publicKey)])
        sendMessage(message, webSocket: webSocket)
    }
    
    func sendChallengeResponse(response: String) {
        if (webSocket == nil) {
            return
        }
        
        // create encrypted data response
        let encryptedData = cryptor.encryptedChallengeResponseDataFromChallengeString(response, nonce: context.nonce, sessionKey: context.sessionKey)
        
        // send challenge response
        sendMessage(messageWithType(MessageType.Challenge, data: ["data": Crypto.Encode.base16StringFromData(encryptedData)]), webSocket: webSocket)
    }
    
    func terminate() {
        if (webSocket == nil) {
            return
        }
        
        // destroy websocket
        disconnectWebSocket()
        delegate?.pairingProtocolManager(self, didTerminateWithOutcome: PairingOutcome.DeviceTerminated)
    }
    
    func createNewPairingItemNamed(name: String) -> PairingKeychainItem? {
        return context.createPairingKeychainItemNamed(name)
    }
    
    // MARK: - Initialization
    
    private func disconnectWebSocket() {
        webSocket?.delegate = nil
        if let isConnected = webSocket?.isConnected where isConnected == true {
            webSocket?.disconnect()
        }
        webSocket = nil
    }
    
    deinit {
        disconnectWebSocket()
        delegate?.pairingProtocolManager(self, didTerminateWithOutcome: PairingOutcome.DeviceTerminated)
    }
    
}

extension PairingProtocolManager {
    
    // MARK: - Messages management
    
    override func handleChallengeMessage(message: Message, webSocket: WebSocket) {
        if let dataString = message["data"] as? String {
            // get data
            let blob = Crypto.Encode.dataFromBase16String(dataString)
            
            // extract nonce and encrypted data
            context.nonce = cryptor.nonceFromBlob(blob)
            let encryptedData = cryptor.encryptedDataFromBlob(blob)
            
            // decrypt data
            let decryptedData = cryptor.decryptData(encryptedData, sessionKey: context.sessionKey)
            
            // extract challenge, pairing key
            let challengeData = cryptor.challengeDataFromDecryptedData(decryptedData)
            context.pairingKey = cryptor.pairingKeyFromDecryptedData(decryptedData)
            
            // create challenge string
            let challengeString = cryptor.challengeStringFromChallengeData(challengeData)
            
            // notify delegate
            delegate?.pairingProtocolManager(self, didReceiveChallenge: challengeString)
        }
    }
    
    override func handlePairingMessage(message: Message, webSocket: WebSocket) {
        if let isSuccessful = message["is_successful"] as? Bool {
            disconnectWebSocket()
            delegate?.pairingProtocolManager(self, didTerminateWithOutcome: isSuccessful ? PairingOutcome.DongleSucceeded : PairingOutcome.DongleFailed)
        }
    }
    
    override func handleDisconnectMessage(message: Message, webSocket: WebSocket) {
        disconnectWebSocket()
        delegate?.pairingProtocolManager(self, didTerminateWithOutcome: PairingOutcome.DongleTerminated)
    }
    
    override func handleRepeatMessage(message: Message, webSocket: WebSocket) {
        if let message = lastSentMessage {
            sendMessage(message, webSocket: webSocket)
        }
    }
    
}

extension PairingProtocolManager {
    
    // MARK: - WebSocket delegate
    
    override func handleWebSocket(webSocket: WebSocket, didDisconnectWithError error: NSError?) {
        self.disconnectWebSocket()
        self.delegate?.pairingProtocolManager(self, didTerminateWithOutcome: PairingOutcome.ServerDisconnected)
    }
    
}