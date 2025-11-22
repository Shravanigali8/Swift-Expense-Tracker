import Foundation
import CoreData

extension ExpenseParticipant {
    /// Creates and returns a new ExpenseParticipant configured with the given user and amount
    /// - Parameters:
    ///   - context: NSManagedObjectContext used to insert the new object
    ///   - user: The user participating in the expense
    ///   - amount: The amount assigned to the user
    /// - Returns: A newly inserted and configured ExpenseParticipant
    static func create(context: NSManagedObjectContext, user: User, amount: Double) -> ExpenseParticipant {
        let participant = ExpenseParticipant(context: context)
        participant.user = user
        participant.amount = NSDecimalNumber(value: amount)
        return participant
    }
}
