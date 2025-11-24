//
//  Extensions.swift
//  ExpenseTracker
//
// Created by Group Cluster
//

import Foundation

extension Double {
    
    var formattedCurrencyText: String {
        return Utils.numberFormatter.string(from: NSNumber(value: self)) ?? "0"
    }
    
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
    
}

extension Notification.Name {
    static let expenseDataChanged = Notification.Name("expenseDataChanged")
}
