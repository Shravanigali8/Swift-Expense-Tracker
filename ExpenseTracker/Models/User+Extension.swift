//
//  User+Extension.swift
//  ExpenseTracker
//
// Created by Group Cluster
//

import Foundation
import CoreData

extension User {
    
    var nameText: String {
        name ?? "Unknown User"
    }
    
    var emailText: String {
        email ?? ""
    }
    
    static func createDefaultUser(context: NSManagedObjectContext, name: String = "You") -> User {
        let user = User(context: context)
        user.id = UUID()
        user.name = name
        user.createdAt = Date()
        return user
    }
    
    static func fetchAll(context: NSManagedObjectContext) -> [User] {
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \User.name, ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching users: \(error.localizedDescription)")
            return []
        }
    }
    
    static func findOrCreate(context: NSManagedObjectContext, name: String) -> User {
        let request: NSFetchRequest<User> = User.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", name)
        request.fetchLimit = 1
        
        if let existing = try? context.fetch(request).first {
            return existing
        }
        
        return createDefaultUser(context: context, name: name)
    }
    
    func totalOwed(to user: User, in group: Group? = nil, context: NSManagedObjectContext? = nil) -> Double {
        guard let context = context ?? managedObjectContext else { return 0 }
        let request: NSFetchRequest<Debt> = Debt.fetchRequest()
        var predicates: [NSPredicate] = [
            NSPredicate(format: "owedBy == %@ AND owedTo == %@ AND isSettled == NO", self, user)
        ]
        
        if let group = group {
            predicates.append(NSPredicate(format: "group == %@", group))
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        
        do {
            let debts = try context.fetch(request)
            return debts.reduce(0) { $0 + ($1.amount?.doubleValue ?? 0) }
        } catch {
            return 0
        }
    }
    
    func totalOwedBy(user: User, in group: Group? = nil, context: NSManagedObjectContext? = nil) -> Double {
        guard let context = context ?? managedObjectContext else { return 0 }
        let request: NSFetchRequest<Debt> = Debt.fetchRequest()
        var predicates: [NSPredicate] = [
            NSPredicate(format: "owedBy == %@ AND owedTo == %@ AND isSettled == NO", user, self)
        ]
        
        if let group = group {
            predicates.append(NSPredicate(format: "group == %@", group))
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        
        do {
            let debts = try context.fetch(request)
            return debts.reduce(0) { $0 + ($1.amount?.doubleValue ?? 0) }
        } catch {
            return 0
        }
    }
    
    func netBalance(in group: Group? = nil, context: NSManagedObjectContext) -> Double {
        let allUsers = User.fetchAll(context: context)
        var balance: Double = 0
        
        for user in allUsers where user != self {
            balance += totalOwedBy(user: user, in: group, context: context)
            balance -= totalOwed(to: user, in: group, context: context)
        }
        
        return balance
    }
}

