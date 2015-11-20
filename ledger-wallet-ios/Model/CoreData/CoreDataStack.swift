//
//  CoreDataStack.swift
//  ledger-wallet-ios
//
//  Created by Nicolas Bigot on 18/11/2015.
//  Copyright © 2015 Ledger. All rights reserved.
//

import Foundation
import CoreData

enum CoreDataStoreType {
    
    case Sqlite
    case Memory
    
    private var systemStoreType: String {
        switch self {
        case .Sqlite: return NSSQLiteStoreType
        case .Memory: return NSInMemoryStoreType
        }
    }
    
    private var requiresFileStorage: Bool {
        switch self {
        case .Memory: return false
        default: return true
        }
    }
    
}

final class CoreDataStack {

    private var logger = Logger.sharedInstance(name: "CoreDataStack")
    private var queue = dispatch_queue_create("co.ledger.ledgerwallet.coredatastack", DISPATCH_QUEUE_SERIAL)

    private var privateManagedObjectContext: NSManagedObjectContext!
    private var mainManagedObjectContext: NSManagedObjectContext!
    private var persistentStoreCoordinator: NSPersistentStoreCoordinator!
    private var persistentStore: NSPersistentStore!
    
    // MARK: Blocks
    
    func performBlock(block: (NSManagedObjectContext) -> Void) {
        dispatch_async(queue) { [weak self] in
            guard let strongSelf = self else { return }
            
            guard let mainManagedObjectContext = strongSelf.mainManagedObjectContext else {
                strongSelf.logger.error("Unable to perform block (no main context)")
                return
            }
            
            mainManagedObjectContext.performBlock() {
                block(mainManagedObjectContext)
            }
        }
    }
    
    // MARK: Emphemaral contexts
    
    func createChildContext() -> NSManagedObjectContext {
        let context = managedObjectContextWithConcurrencyType(.PrivateQueueConcurrencyType)
        
        dispatch_sync(queue) { [weak self] in
            guard let strongSelf = self else { return }
            
            guard let mainManagedObjectContext = strongSelf.mainManagedObjectContext else {
                strongSelf.logger.error("Unable to create new child context (no main context)")
                return
            }
            context.parentContext = mainManagedObjectContext
        }
        return context
    }

    // MARK: Persistence
    
    func saveAndWait(wait: Bool) {
        // choose dispatch method
        let dispatchMethod: (dispatch_queue_t, dispatch_block_t) -> Void
        if wait {
            dispatchMethod = dispatch_sync
        }
        else {
            dispatchMethod = dispatch_async
        }
        
        dispatchMethod(queue) { [weak self] in
            guard let strongSelf = self else { return }
            
            guard let mainManagedObjectContext = strongSelf.mainManagedObjectContext, privateManagedObjectContext = strongSelf.privateManagedObjectContext else {
                strongSelf.logger.error("Unable to save (no main or private context)")
                return
            }
            
            guard mainManagedObjectContext.hasChanges || privateManagedObjectContext.hasChanges else {
                return
            }
            
            // choose perform method
            let performMethod: NSManagedObjectContext -> (() -> Void) -> Void
            if wait {
                performMethod = NSManagedObjectContext.performBlockAndWait
            }
            else {
                performMethod = NSManagedObjectContext.performBlock
            }
            
            // perform save
            performMethod(mainManagedObjectContext)() {
                do {
                    try mainManagedObjectContext.save()
                }
                catch {
                    strongSelf.logger.error("Unable to save main context \(error)")
                    return
                }
                privateManagedObjectContext.performBlock() {
                    do {
                        try privateManagedObjectContext.save()
                    }
                    catch {
                        strongSelf.logger.error("Unable to save private context \(error)")
                        return
                    }
                }
            }
        }
    }
    
    // MARK: Stack opening

    private func createDatabasesDirectory() -> Bool {
        let fileManager = NSFileManager.defaultManager()
        let databasesPath = ApplicationManager.sharedInstance.databasesDirectoryPath
        if !fileManager.fileExistsAtPath(databasesPath) {
            do {
                try fileManager.createDirectoryAtPath(databasesPath, withIntermediateDirectories: true, attributes: nil)
            }
            catch {
                logger.error("Unable to create databases directory at path \(databasesPath) \(error)")
                return false
            }
        }
        return true
    }
    
    private func initializeContextsWithModelName(modelName: String) -> Bool {
        guard let modelURL = NSBundle.mainBundle().URLForResource(modelName, withExtension: "momd") else {
            logger.error("Unable to locate model with name \"\(modelName)\"")
            return false
        }
        
        guard let managedObjectModel = NSManagedObjectModel(contentsOfURL: modelURL) else {
            logger.error("Unable to create object model at URL \(modelURL)")
            return false
        }
        logger.info("Model URL: \(modelURL)")
        
        // create contexts
        persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
        mainManagedObjectContext = managedObjectContextWithConcurrencyType(.MainQueueConcurrencyType)
        privateManagedObjectContext = managedObjectContextWithConcurrencyType(.PrivateQueueConcurrencyType)
        
        // setup stack
        privateManagedObjectContext.persistentStoreCoordinator = persistentStoreCoordinator
        mainManagedObjectContext.parentContext = privateManagedObjectContext
        
        return true
    }
    
    private func initializePersistentStoreWithType(storeType: CoreDataStoreType) -> Bool {
        // add persistent store
        do {
            if storeType.requiresFileStorage {
                let databaseURL = NSURL(fileURLWithPath: (ApplicationManager.sharedInstance.databasesDirectoryPath as NSString).stringByAppendingPathComponent(LedgerSqliteDatabaseName + ".sqlite"))
                let options = [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true]
                persistentStore = try persistentStoreCoordinator.addPersistentStoreWithType(storeType.systemStoreType, configuration: nil, URL: databaseURL, options: options)
                logger.info("Database URL: \(databaseURL)")
            }
            else {
                persistentStore = try persistentStoreCoordinator.addPersistentStoreWithType(storeType.systemStoreType, configuration: nil, URL: nil, options: nil)
            }
        }
        catch {
            logger.error("Unable to initialize stack with type \"\(storeType)\" \(error)")
            return false
        }
        return true
    }
    
    // MARK: Utils
    
    private func managedObjectContextWithConcurrencyType(concurrencyType: NSManagedObjectContextConcurrencyType) -> NSManagedObjectContext {
        let context = NSManagedObjectContext(concurrencyType: concurrencyType)
        context.undoManager = nil
        return context
    }
    
    // MARK: Initialization
    
    init(storeType: CoreDataStoreType, modelName: String) {
        guard createDatabasesDirectory() else {
            return
        }
        
        guard initializeContextsWithModelName(modelName) else {
            return
        }
        
        dispatch_async(queue) { [weak self] in
            guard let strongSelf = self else { return }
            
            // initialize persistent store
            guard strongSelf.initializePersistentStoreWithType(storeType) == true else {
                return
            }
        }
    }

}