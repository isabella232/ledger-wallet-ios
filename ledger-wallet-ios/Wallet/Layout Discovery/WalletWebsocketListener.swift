//
//  WalletWebsocketListener.swift
//  ledger-wallet-ios
//
//  Created by Nicolas Bigot on 25/11/2015.
//  Copyright © 2015 Ledger. All rights reserved.
//

import Foundation

protocol WalletWebsocketListenerDelegate: class {
    
    func websocketListenerDidStart(websocketListener: WalletWebsocketListener)
    func websocketListenerDidStop(websocketListener: WalletWebsocketListener)
    func websocketListener(websocketListener: WalletWebsocketListener, didReceiveTransaction transaction: WalletRemoteTransaction)
    
}

final class WalletWebsocketListener {
    
    weak var delegate: WalletWebsocketListenerDelegate?
    private var websocket: WebSocket!
    private var listening = false
    private let delegateQueue: NSOperationQueue
    private let workingQueue = dispatchSerialQueueWithName(dispatchQueueNameForIdentifier("WalletWebsocketListener"))
    private let logger = Logger.sharedInstance(name: "WalletWebsocketListener")
    
    var isListening: Bool {
        var value = false
        dispatchSyncOnQueue(workingQueue) { [weak self] in
            guard let strongSelf = self else { return }
            value = strongSelf.listening
        }
        return value
    }
    
    func startListening() {
        dispatchAsyncOnQueue(workingQueue) { [weak self] in
            guard let strongSelf = self where !strongSelf.listening else { return }
            
            strongSelf.logger.info("Start listening transactions")
            strongSelf.listening = true
            strongSelf.websocket = WebSocket(url: NSURL(string: "wss://socket.blockcypher.com/v1/btc/main")!)
            strongSelf.websocket.delegate = self
            strongSelf.websocket.queue = strongSelf.workingQueue
            strongSelf.websocket.connect()
            
            // notify delegate
            strongSelf.delegateQueue.addOperationWithBlock() { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.delegate?.websocketListenerDidStart(strongSelf)
            }
        }
    }
    
    func stopListening() {
        dispatchAsyncOnQueue(workingQueue) { [weak self] in
            guard let strongSelf = self where strongSelf.listening else { return }

            strongSelf.logger.info("Stop listening transactions")
            strongSelf.listening = false
            strongSelf.websocket.disconnect()
            strongSelf.websocket = nil
            
            // notify delegate
            strongSelf.delegateQueue.addOperationWithBlock() { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.delegate?.websocketListenerDidStop(strongSelf)
            }
        }
    }
    
    // MARK: Initialization
    
    init(delegateQueue: NSOperationQueue) {
        self.delegateQueue = delegateQueue
    }
    
    deinit {
        stopListening()
        dispatchSyncOnQueue(workingQueue, block: {})
    }

}

// MARK: - WebSocketDelegate

extension WalletWebsocketListener: WebSocketDelegate {
    
    func websocketDidConnect(socket: WebSocket) {
        guard listening else { return }
        
        socket.writeString("{\"id\": \"\(NSUUID().UUIDString)\", \"event\": \"unconfirmed-tx\"}")
    }
    
    func websocketDidDisconnect(socket: WebSocket, error: NSError?) {
        guard listening else { return }

        dispatchAfter(3, queue: workingQueue) { [weak self] in
            guard let strongSelf = self where strongSelf.listening else { return }

            strongSelf.logger.info("Lost connection, retrying in 3 seconds")
            strongSelf.stopListening()
            strongSelf.startListening()
        }
    }
    
    func websocketDidReceiveMessage(socket: WebSocket, text: String) {
        guard listening else { return }

        guard let data = text.dataUsingEncoding(NSUTF8StringEncoding) else { return }
        guard let JSON = JSON.JSONObjectFromData(data) as? WalletRemoteTransaction else { return }
        
        delegateQueue.addOperationWithBlock() { [weak self] in
            guard let strongSelf = self where strongSelf.listening else { return }
            strongSelf.delegate?.websocketListener(strongSelf, didReceiveTransaction: JSON)
        }
    }
    
    func websocketDidReceiveData(socket: WebSocket, data: NSData) {
        guard listening else { return }
    }
    
}