//
//  ExpenseLog+Extension.swift
//  ExpenseTracker
//
// Created by Group Cluster
//

import Foundation
import CoreData

extension ExpenseLog {
    
    var categoryEnum: Category {
        Category(rawValue: category ?? "") ?? .other
    }
    
    var dateText: String {
        Utils.dateFormatter.localizedString(for: date ?? Date(), relativeTo: Date())
    }
    
    var nameText: String {
        name ?? ""
    }
    
    var amountText: String {
        Utils.numberFormatter.string(from: NSNumber(value: amount?.doubleValue ?? 0)) ?? ""
    }
    
    var isGroupExpenseValue: Bool {
        isGroupExpense
    }
    
    var groupExpense: Group? {
        group
    }
    
    var paidByUser: User? {
        paidBy
    }
    
    var participantsArray: [ExpenseParticipant] {
        guard let participantsSet = participants as? Set<ExpenseParticipant> else { return [] }
        return Array(participantsSet)
    }
    
    var participantsTotal: Double {
        participantsArray.reduce(Double(0)) { (result: Double, participant: ExpenseParticipant) -> Double in
            result + Double(participant.amountValue)
        }
    }
    
    /// Validates that participant amounts add up to the expense total
    var isSplitValid: Bool {
        let totalAmount = amount?.doubleValue ?? 0
        let participantsTotal = self.participantsTotal
        return abs(participantsTotal - totalAmount) < 0.01
    }
    
    /// Gets the split difference (participants total - expense total)
    var splitDifference: Double {
        let totalAmount = amount?.doubleValue ?? 0
        return participantsTotal - totalAmount
    }
    
    /// Gets the user's split amount for this expense
    /// For group expenses: returns the user's participant amount
    /// For non-group expenses: returns the full expense amount
    func userSplitAmount(for user: User) -> Double {
        if isGroupExpense, let group = group {
            // For group expenses, find the user's participant amount
            if let participant = participantsArray.first(where: { $0.user == user }) {
                return participant.amountValue
            }
            // If user is not a participant, they don't owe anything
            return 0
        } else {
            // For non-group expenses, return the full amount
            return amount?.doubleValue ?? 0
        }
    }
    
    static func fetchAllCategoriesTotalAmountSum(context: NSManagedObjectContext, completion: @escaping ([(sum: Double, category: Category)]) -> ()) {
        let keypathAmount = NSExpression(forKeyPath: \ExpenseLog.amount)
        let expression = NSExpression(forFunction: "sum:", arguments: [keypathAmount])
        
        let sumDesc = NSExpressionDescription()
        sumDesc.expression = expression
        sumDesc.name = "sum"
        sumDesc.expressionResultType = .decimalAttributeType
        
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: ExpenseLog.entity().name ?? "ExpenseLog")
        request.returnsObjectsAsFaults = false
        request.propertiesToGroupBy = ["category"]
        request.propertiesToFetch = [sumDesc, "category"]
        request.resultType = .dictionaryResultType
        
        context.perform {
            do {
                let results = try request.execute()
                let data = results.map { (result) -> (Double, Category)? in
                    guard
                        let resultDict = result as? [String: Any],
                        let amount = resultDict["sum"] as? Double,
                        let categoryKey = resultDict["category"] as? String,
                        let category = Category(rawValue: categoryKey) else {
                            return nil
                    }
                    return (amount, category)
                }.compactMap { $0 }
                
                // Ensure completion is called on main thread for UI updates
                DispatchQueue.main.async {
                    completion(data)
                }
            } catch let error as NSError {
                print((error.localizedDescription))
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
        
    }
    
    /// Fetches category totals showing only the user's split portion
    /// For group expenses: only counts the user's participant amount
    /// For non-group expenses: counts the full expense amount
    static func fetchUserSplitCategoriesTotalAmountSum(context: NSManagedObjectContext, user: User, completion: @escaping ([(sum: Double, category: Category)]) -> ()) {
        // Get user's object ID to fetch it in the perform block's context
        let userObjectID = user.objectID
        
        let request: NSFetchRequest<ExpenseLog> = ExpenseLog.fetchRequest()
        request.returnsObjectsAsFaults = false
        // Prefetch participants and user relationships to ensure they're loaded
        request.relationshipKeyPathsForPrefetching = ["participants", "participants.user", "group"]
        
        context.perform {
            do {
                // Get the user object in this context to avoid cross-context access
                guard let userInContext = try? context.existingObject(with: userObjectID) as? User else {
                    completion([])
                    return
                }
                
                let expenses = try request.execute()
                
                // Group by category and sum user's split amounts
                var categorySums: [Category: Double] = [:]
                
                for expense in expenses {
                    let userAmount = expense.userSplitAmount(for: userInContext)
                    if userAmount > 0 {
                        let category = expense.categoryEnum
                        categorySums[category, default: 0] += userAmount
                    }
                }
                
                // Convert to array of tuples
                let results = categorySums.map { (category, sum) -> (Double, Category) in
                    return (sum, category)
                }
                
                // Ensure completion is called on main thread for UI updates
                DispatchQueue.main.async {
                    completion(results)
                }
            } catch let error as NSError {
                print("Error fetching user split amounts: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }
    
    static func predicate(with categories: [Category], searchText: String, group: Group? = nil, isGroupExpense: Bool? = nil) -> NSPredicate? {
        var predicates = [NSPredicate]()
        
        if !categories.isEmpty {
            let categoriesString = categories.map { $0.rawValue }
            predicates.append(NSPredicate(format: "category IN %@", categoriesString))
        }
        
        if !searchText.isEmpty {
            predicates.append(NSPredicate(format: "name CONTAINS[cd] %@", searchText.lowercased()))
        }
        
        if let group = group {
            predicates.append(NSPredicate(format: "group == %@", group))
        }
        
        if let isGroupExpense = isGroupExpense {
            predicates.append(NSPredicate(format: "isGroupExpense == %@", NSNumber(value: isGroupExpense)))
        }
        
        if predicates.isEmpty {
            return nil
        } else {
            return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
    }
    
    func splitEqually(among users: [User], context: NSManagedObjectContext) {
        guard !users.isEmpty else { return }
        
        let totalAmount = amount?.doubleValue ?? 0
        guard totalAmount > 0 else { return }
        
        // Calculate base amount per person
        let baseAmount = totalAmount / Double(users.count)
        // Round to 2 decimal places
        let roundedBase = (baseAmount * 100).rounded() / 100
        
        // Remove existing participants
        if let existingParticipants = participants as? Set<ExpenseParticipant> {
            for participant in existingParticipants {
                context.delete(participant)
            }
        }
        
        // Create new participants with proper rounding
        var newParticipants: [ExpenseParticipant] = []
        var distributedTotal: Double = 0
        
        // Distribute to all but the last person
        for i in 0..<(users.count - 1) {
            let user = users[i]
            let participant = ExpenseParticipant.create(context: context, user: user, amount: roundedBase)
            participant.expense = self
            newParticipants.append(participant)
            distributedTotal += roundedBase
        }
        
        // Last person gets the remainder to ensure exact total
        if let lastUser = users.last {
            let remainder = totalAmount - distributedTotal
            let participant = ExpenseParticipant.create(context: context, user: lastUser, amount: remainder)
            participant.expense = self
            newParticipants.append(participant)
        }
        
        self.participants = NSSet(array: newParticipants)
    }
    
    func splitByAmounts(amounts: [User: Double], context: NSManagedObjectContext) {
        guard !amounts.isEmpty else { return }
        
        let totalAmount = amount?.doubleValue ?? 0
        guard totalAmount > 0 else { return }
        
        // Remove existing participants
        if let existingParticipants = participants as? Set<ExpenseParticipant> {
            for participant in existingParticipants {
                context.delete(participant)
            }
        }
        
        // Calculate total of provided amounts
        let providedTotal = amounts.values.reduce(0, +)
        
        // Normalize amounts if they don't match total (proportionally adjust)
        var normalizedAmounts: [User: Double] = [:]
        if providedTotal > 0 && abs(providedTotal - totalAmount) > 0.01 {
            // Adjust proportionally
            let ratio = totalAmount / providedTotal
            for (user, amount) in amounts {
                normalizedAmounts[user] = (amount * ratio).rounded(toPlaces: 2)
            }
            
            // Ensure exact total by adjusting the last entry
            let normalizedTotal = normalizedAmounts.values.reduce(0, +)
            let normalizedKeys = Array(normalizedAmounts.keys)
            if let lastUser = normalizedKeys.last {
                let adjustment = totalAmount - normalizedTotal
                normalizedAmounts[lastUser] = (normalizedAmounts[lastUser] ?? 0) + adjustment
            }
        } else {
            normalizedAmounts = amounts
            // If amounts don't add up, adjust the last one
            let currentTotal = amounts.values.reduce(0, +)
            if abs(currentTotal - totalAmount) > 0.01 {
                let amountKeys = Array(amounts.keys)
                if let lastUser = amountKeys.last {
                    let adjustment = totalAmount - currentTotal
                    normalizedAmounts[lastUser] = (normalizedAmounts[lastUser] ?? 0) + adjustment
                }
            }
        }
        
        // Create new participants
        var newParticipants: [ExpenseParticipant] = []
        for (user, amount) in normalizedAmounts {
            // Only create participant if amount is positive
            guard amount > 0 else { continue }
            let participant = ExpenseParticipant.create(context: context, user: user, amount: amount)
            participant.expense = self
            newParticipants.append(participant)
        }
        
        self.participants = NSSet(array: newParticipants)
    }
    
    /// Clears all splits from the expense
    /// For group expenses: also reverses the associated debts
    func clearSplit(context: NSManagedObjectContext) {
        // Reverse debts if this is a group expense with participants
        if isGroupExpense, let group = group, !participantsArray.isEmpty {
            Debt.reverseDebts(from: self, context: context)
        }
        
        // Remove all participants
        if let existingParticipants = participants as? Set<ExpenseParticipant> {
            for participant in existingParticipants {
                context.delete(participant)
            }
        }
        
        self.participants = NSSet()
    }
    
    /// Deletes the expense and all associated data (participants, debts)
    func deleteExpense(context: NSManagedObjectContext) {
        // Reverse debts if this is a group expense
        if isGroupExpense, let group = group, !participantsArray.isEmpty {
            Debt.reverseDebts(from: self, context: context)
        }
        
        // Delete all participants (they will cascade delete, but we'll be explicit)
        if let existingParticipants = participants as? Set<ExpenseParticipant> {
            for participant in existingParticipants {
                context.delete(participant)
            }
        }
        
        // Delete the expense itself
        context.delete(self)
    }
    
}
