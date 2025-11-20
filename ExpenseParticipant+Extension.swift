import Foundation
import CoreData

extension ExpenseParticipant {
    
    var amountValue: Double {
        return amount?.doubleValue ?? 0
    }
    
    var amountText: String {
        return amount?.stringValue ?? "0"
    }
    
    var userSafe: User? {
        return user
    }
    
    /// Convenience factory to create a participant with user and amount
    /// - Parameters:
    ///   - context: The managed object context to insert into
    ///   - user: The user participating in the expense
    ///   - amount: The amount owed/paid by the participant
    /// - Returns: A newly created `ExpenseParticipant` inserted in the context
    static func create(context: NSManagedObjectContext, user: User, amount: Double) -> ExpenseParticipant {
        let participant = ExpenseParticipant(context: context)
        participant.id = UUID()
        participant.user = user
        participant.amount = NSDecimalNumber(value: amount)
        return participant
    }
}
