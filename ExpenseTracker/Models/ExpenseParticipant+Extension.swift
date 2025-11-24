//
//  ExpenseParticipant+Extension.swift
//  ExpenseTracker
//
// Created by Group Cluster
//

import Foundation
import CoreData

extension ExpenseParticipant {
    
    var amountValue: Double {
        amount?.doubleValue ?? 0
    }
    
    static func create(context: NSManagedObjectContext, user: User, amount: Double) -> ExpenseParticipant {
        let participant = ExpenseParticipant(context: context)
        participant.id = UUID()
        participant.user = user
        participant.amount = NSDecimalNumber(value: amount)
        return participant
    }
}

