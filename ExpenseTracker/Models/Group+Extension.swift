//
//  Group+Extension.swift
//  ExpenseTracker
//
// Created by Group Cluster
//

import Foundation
import CoreData

extension Group {
    
    var nameText: String {
        name ?? "Unnamed Group"
    }
    
    var membersArray: [User] {
        guard let members = members as? Set<User> else { return [] }
        return Array(members).sorted { ($0.name ?? "") < ($1.name ?? "") }
    }
    
    var expensesArray: [ExpenseLog] {
        guard let expenses = expenses as? Set<ExpenseLog> else { return [] }
        return Array(expenses).sorted { ($0.date ?? Date.distantPast) > ($1.date ?? Date.distantPast) }
    }
    
    var totalExpenses: Double {
        expensesArray.reduce(0) { $0 + ($1.amount?.doubleValue ?? 0) }
    }
    
    static func create(context: NSManagedObjectContext, name: String, members: [User]) -> Group {
        let group = Group(context: context)
        group.id = UUID()
        group.name = name
        group.createdAt = Date()
        group.members = NSSet(array: members)
        return group
    }
    
    static func fetchAll(context: NSManagedObjectContext) -> [Group] {
        let request: NSFetchRequest<Group> = Group.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Group.createdAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching groups: \(error.localizedDescription)")
            return []
        }
    }
    
    func addMember(_ user: User) {
        guard let members = members as? NSMutableSet else { return }
        members.add(user)
    }
    
    func removeMember(_ user: User) {
        guard let members = members as? NSMutableSet else { return }
        members.remove(user)
    }
    
    func hasMember(_ user: User) -> Bool {
        guard let members = members as? Set<User> else { return false }
        return members.contains(user)
    }
}

