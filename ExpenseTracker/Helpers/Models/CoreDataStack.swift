//
//  CoreDataStack.swift
//  ExpenseTracker
//
//  Created by Alfian Losari on 19/04/20.
//  Copyright © 2020 Alfian Losari. All rights reserved.
//

import CoreData

class CoreDataStack {
    
    private let containerName: String
    var viewContext: NSManagedObjectContext { persistentContainer.viewContext }
    
    private lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: containerName)
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                print("Core Data error: \(error.localizedDescription)")
                print("Error details: \(error.userInfo)")
                
                // For development: If migration fails, delete the old store
                // Remove this in production and implement proper migration
                #if DEBUG
                if let url = storeDescription.url {
                    let fileManager = FileManager.default
                    let storeURL = url
                    let shmURL = storeURL.appendingPathExtension("shm")
                    let walURL = storeURL.appendingPathExtension("wal")
                    
                    do {
                        try fileManager.removeItem(at: storeURL)
                        try? fileManager.removeItem(at: shmURL)
                        try? fileManager.removeItem(at: walURL)
                        print("Deleted old database. Please restart the app.")
                    } catch {
                        print("Failed to delete old database: \(error)")
                    }
                }
                #endif
            }
            print(storeDescription)
        })
        return container
    }()
    
    init(containerName: String) {
        self.containerName = containerName
        _ = persistentContainer
    }
}

extension NSManagedObjectContext {
    
    func saveContext() throws {
        guard hasChanges else { return }
        try save()
    }
}
