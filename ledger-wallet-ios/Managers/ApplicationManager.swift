//
//  ApplicationManager.swift
//  ledger-wallet-ios
//
//  Created by Nicolas Bigot on 13/02/2015.
//  Copyright (c) 2015 Ledger. All rights reserved.
//

import Foundation

final class ApplicationManager {
    
    static let sharedInstance = ApplicationManager()
    
    var UUID: String {
        if let uuid = preferences.stringForKey("uuid") {
            return uuid
        }
        let uuid = NSUUID().UUIDString
        preferences.setObject(uuid, forKey: "uuid")
        return uuid
    }
    var bundleIdentifier: String { return NSBundle.mainBundle().bundleIdentifier ?? "" }
    var disablesIdleTimer: Bool {
        get {
            return UIApplication.sharedApplication().idleTimerDisabled
        }
        set {
            UIApplication.sharedApplication().idleTimerDisabled = newValue
        }
    }
    
    var libraryDirectoryPath: String { return NSSearchPathForDirectoriesInDomains(.LibraryDirectory, .UserDomainMask, true)[0] }
    var temporaryDirectoryPath: String { return NSTemporaryDirectory() }
    var logsDirectoryPath: String { return (libraryDirectoryPath as NSString).stringByAppendingPathComponent("Logs") }
    
    private lazy var preferences = Preferences(storeName: "ApplicationManager")
    private lazy var networkActivitiesCount = 0
    private lazy var logger = Logger.sharedInstance(name: "ApplicationManager")
    
    // MARK: Utilities
    
    func handleLaunchWithOptions(launchOptions: [NSObject: AnyObject]?) {
        // print application path if needed
        #if DEBUG
            logger.info(libraryDirectoryPath)
        #endif
        
        // if app hasn't been launched befores
        if !preferences.boolForKey("already_launched") {
            preferences.setBool(true, forKey: "already_launched")
            
            // delete all pairing keychain items
            PairingKeychainItem.destroyAll()
        }
    }

    func clearTemporaryDirectory() {
        let directoryPath = self.temporaryDirectoryPath
        let fileManager = NSFileManager.defaultManager()
        
        if !fileManager.fileExistsAtPath(directoryPath) {
            return
        }
        
        if var content = (try? fileManager.contentsOfDirectoryAtPath(directoryPath)) {
            content = content.filter({ !$0.hasPrefix(".") })
            for file in content {
                let filepath = (directoryPath as NSString).stringByAppendingPathComponent(file)
                do {
                    try fileManager.removeItemAtPath(filepath)
                } catch _ {
                }
            }
        }
    }
    
    // MARK: Network activity indicator
    
    func startNetworkActivity() {
        dispatchAsyncOnMainQueue() {
            self.networkActivitiesCount++
            self.updateNetworkActivityIndicator()
        }
    }
    
    func stopNetworkActivity() {
        dispatchAsyncOnMainQueue() {
            if self.networkActivitiesCount > 0 {
                self.networkActivitiesCount--
                self.updateNetworkActivityIndicator()
            }
        }
    }
    
    private func updateNetworkActivityIndicator() {
        UIApplication.sharedApplication().networkActivityIndicatorVisible = networkActivitiesCount > 0
    }
    
    // MARK: Initialization
    
    private init() {
        
    }
    
}