//
//  Created by Zsombor Szabo on 12/03/2020.
//
//

import Foundation
import CoreData
import UIKit

public class PersistentContainer: NSPersistentContainer {
    
    static let modelName = "CovidWatch"
    
    public static var shared = PersistentContainer(name: modelName)
    
    public var isLoaded = false
    
    public var isLoading = false
    
    public var loadError: Error? //= (CocoaError(.coderInvalidValue) as NSError)
    
    var loadCompletionHandlers = [((Error?) -> Void)]()
    
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier?

    // swiftlint:disable:next function_body_length
    public func load(_ completionHandler: @escaping (Error?) -> Void) {
        let container = self
        if let error = container.loadError {
            DispatchQueue.main.async { completionHandler(error) }
            return
        }
        guard !container.isLoaded else {
            DispatchQueue.main.async { completionHandler(nil) }
            return
        }
        container.loadCompletionHandlers.append(completionHandler)
        guard !container.isLoading else {
            return
        }
        container.isLoading = true
        
        let storeDescription = container.persistentStoreDescriptions.first
        storeDescription?.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
                
        self.backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask { [weak self] in
            guard let self = self else { return }
            LogManager.sharedManager.writeLog(entry: LogEntry(source: self, level: .info, message: "Did expire background task=\(self.backgroundTaskIdentifier?.rawValue ?? 0)"))
        }
        LogManager.sharedManager.writeLog(entry: LogEntry(source: self, message: "Loading persistent stores background task=\(self.backgroundTaskIdentifier?.rawValue ?? 0)..."))
        container.loadPersistentStores(completionHandler: { (_, error) in
            defer {
                if let identifier = self.backgroundTaskIdentifier {
                    UIApplication.shared.endBackgroundTask(identifier)
                    self.backgroundTaskIdentifier = nil
                }
                container.isLoading = false
                container.loadCompletionHandlers.forEach { $0(error) }
            }
            if let error = error {
                LogManager.sharedManager.writeLog(entry: LogEntry(source: self, level: .error, message: "Loading persistent stores failed: \(error)"))
                container.loadError = error
                return
            }
            container.isLoaded = true
            LogManager.sharedManager.writeLog(entry: LogEntry(source: self, message: "Loading persistent stores completed"))

            container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
            container.viewContext.automaticallyMergesChangesFromParent = true
        })
    }
    
    public func delete() {
        let fileManager = FileManager.default
        do {
            let applicationDataDirectoryURL = PersistentContainer.defaultDirectoryURL()
            let dataPath = applicationDataDirectoryURL
                .appendingPathComponent("\(PersistentContainer.modelName).sqlite").path
            if fileManager.fileExists(atPath: dataPath) {
                try fileManager.removeItem(atPath: dataPath)
            }
            let shmPath = applicationDataDirectoryURL
                .appendingPathComponent("\(PersistentContainer.modelName).sqlite-shm").path
            if fileManager.fileExists(atPath: shmPath) {
                try fileManager.removeItem(atPath: shmPath)
            }
            let walPath = applicationDataDirectoryURL
                .appendingPathComponent("\(PersistentContainer.modelName).sqlite-wal").path
            if fileManager.fileExists(atPath: walPath) {
                try fileManager.removeItem(atPath: walPath)
            }
        } catch {
            LogManager.sharedManager.writeLog(entry: LogEntry(source: self, level: .error, message: "Deleting data failed: \(error)"))
        }
    }
    
    func saveContext () {
        let context = self.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                UIApplication.shared.topViewController?.present(error as NSError, animated: true)
            }
        }
    }
}
