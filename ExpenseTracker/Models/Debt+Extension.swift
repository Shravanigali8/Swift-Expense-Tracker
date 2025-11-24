//
//  Debt+Extension.swift
//  ExpenseTracker
//
// Created by Group Cluster
//

import Foundation
import CoreData

extension Debt {
    
    var amountValue: Double {
        amount?.doubleValue ?? 0
    }
    
    var isSettledValue: Bool {
        isSettled
    }
    
    static func create(context: NSManagedObjectContext, owedBy: User, owedTo: User, amount: Double, group: Group? = nil) -> Debt {
        let debt = Debt(context: context)
        debt.id = UUID()
        debt.amount = NSDecimalNumber(value: amount)
        debt.owedBy = owedBy
        debt.owedTo = owedTo
        debt.group = group
        debt.isSettled = false
        debt.createdAt = Date()
        return debt
    }
    
    static func fetchAll(context: NSManagedObjectContext, group: Group? = nil, includeSettled: Bool = false) -> [Debt] {
        let request: NSFetchRequest<Debt> = Debt.fetchRequest()
        var predicates: [NSPredicate] = []
        
        if let group = group {
            predicates.append(NSPredicate(format: "group == %@", group))
        }
        
        if !includeSettled {
            predicates.append(NSPredicate(format: "isSettled == NO"))
        }
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Debt.createdAt, ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching debts: \(error.localizedDescription)")
            return []
        }
    }
    
    func settle() {
        isSettled = true
        settledAt = Date()
    }
    
    /// Reverses debts created from an expense (used when editing expenses)
    static func reverseDebts(from expense: ExpenseLog, context: NSManagedObjectContext) {
        guard let paidBy = expense.paidBy,
              let participants = expense.participants as? Set<ExpenseParticipant>,
              let group = expense.group else { return }
        
        for participant in participants {
            guard let user = participant.user,
                  user != paidBy,
                  let participantAmount = participant.amount?.doubleValue,
                  participantAmount > 0 else { continue }
            
            // Find and reverse the debt
            let existingDebt = findDebt(owedBy: user, owedTo: paidBy, in: group, context: context)
            
            if let debt = existingDebt {
                let currentAmount = debt.amount?.doubleValue ?? 0
                let newAmount = currentAmount - participantAmount
                
                if newAmount <= 0.01 {
                    // Delete debt if reversed amount is zero or negative
                    context.delete(debt)
                } else {
                    // Update debt with reduced amount
                    debt.amount = NSDecimalNumber(value: newAmount)
                }
            }
        }
        
        // Simplify debts after reversal
        simplifyDebts(in: group, context: context)
    }
    
    static func calculateAndCreateDebts(from expense: ExpenseLog, context: NSManagedObjectContext) {
        guard let paidBy = expense.paidBy,
              let participants = expense.participants as? Set<ExpenseParticipant>,
              let group = expense.group else { return }
        
        let totalAmount = expense.amount?.doubleValue ?? 0
        
        for participant in participants {
            guard let user = participant.user,
                  user != paidBy,
                  let participantAmount = participant.amount?.doubleValue,
                  participantAmount > 0 else { continue }
            
            // Check if debt already exists
            let existingDebt = findDebt(owedBy: user, owedTo: paidBy, in: group, context: context)
            
            if let debt = existingDebt {
                // Update existing debt
                let newAmount = (debt.amount?.doubleValue ?? 0) + participantAmount
                debt.amount = NSDecimalNumber(value: newAmount)
            } else {
                // Create new debt
                _ = Debt.create(context: context, owedBy: user, owedTo: paidBy, amount: participantAmount, group: group)
            }
        }
        
        // Simplify debts (minimize transactions)
        simplifyDebts(in: group, context: context)
    }
    
    static func findDebt(owedBy: User, owedTo: User, in group: Group, context: NSManagedObjectContext) -> Debt? {
        let request: NSFetchRequest<Debt> = Debt.fetchRequest()
        request.predicate = NSPredicate(format: "owedBy == %@ AND owedTo == %@ AND group == %@ AND isSettled == NO", owedBy, owedTo, group)
        request.fetchLimit = 1
        
        return try? context.fetch(request).first
    }
    
    static func simplifyDebts(in group: Group, context: NSManagedObjectContext) {
        let debts = Debt.fetchAll(context: context, group: group, includeSettled: false)
        let members = group.membersArray
        
        // Create a balance map
        var balances: [User: Double] = [:]
        for member in members {
            balances[member] = 0
        }
        
        // Calculate net balances
        for debt in debts {
            guard let owedBy = debt.owedBy, let owedTo = debt.owedTo else { continue }
            let amount = debt.amountValue
            balances[owedBy, default: 0] -= amount
            balances[owedTo, default: 0] += amount
        }
        
        // Delete all existing debts in the group
        for debt in debts {
            context.delete(debt)
        }
        
        // Create simplified debts
        var creditors: [(User, Double)] = []
        var debtors: [(User, Double)] = []
        
        for (user, balance) in balances {
            if balance > 0.01 {
                creditors.append((user, balance))
            } else if balance < -0.01 {
                debtors.append((user, abs(balance)))
            }
        }
        
        // Match creditors with debtors
        var creditorIndex = 0
        var debtorIndex = 0
        
        while creditorIndex < creditors.count && debtorIndex < debtors.count {
            let (creditor, creditAmount) = creditors[creditorIndex]
            let (debtor, debtAmount) = debtors[debtorIndex]
            
            let settlement = min(creditAmount, debtAmount)
            
            if settlement > 0.01 {
                _ = Debt.create(context: context, owedBy: debtor, owedTo: creditor, amount: settlement, group: group)
            }
            
            if creditAmount - settlement < 0.01 {
                creditorIndex += 1
            } else {
                creditors[creditorIndex].1 = creditAmount - settlement
            }
            
            if debtAmount - settlement < 0.01 {
                debtorIndex += 1
            } else {
                debtors[debtorIndex].1 = debtAmount - settlement
            }
        }
    }
}

