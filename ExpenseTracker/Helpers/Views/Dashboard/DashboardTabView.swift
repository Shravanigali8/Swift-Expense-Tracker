//
//  DashboardTabView.swift
//  ExpenseTracker
//
//  Created by Alfian Losari on 19/04/20.
//  Copyright © 2020 Alfian Losari. All rights reserved.
//

import SwiftUI
import CoreData
import Combine

struct DashboardTabView: View {
    
    @Environment(\.managedObjectContext)
    var context: NSManagedObjectContext
    
    @State var totalExpenses: Double?
    @State var categoriesSum: [CategorySum]?
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                if totalExpenses != nil {
                    Text("Your Split")
                        .font(.headline)
                    if totalExpenses != nil {
                        Text(totalExpenses!.formattedCurrencyText)
                            .font(.largeTitle)
                    }
                }
            }
            
            if categoriesSum != nil {
                if totalExpenses != nil && totalExpenses! > 0 {
                    PieChartView(
                        data: categoriesSum!.map { ($0.sum, $0.category.color) },
                        style: Styles.pieChartStyleOne,
                        form: CGSize(width: 300, height: 240),
                        dropShadow: false
                    )
                }
                
                Divider()

                List {
                    Text("Breakdown").font(.headline)
                    ForEach(self.categoriesSum!) {
                        CategoryRowView(category: $0.category, sum: $0.sum)
                    }
                }
            }
            
            if totalExpenses == nil && categoriesSum == nil {
                Text("No expenses data\nPlease add your expenses from the logs tab")
                    .multilineTextAlignment(.center)
                    .font(.headline)
                    .padding(.horizontal)
            }
        }
        .padding(.top)
        .onAppear(perform: fetchTotalSums)
        .onReceive(NotificationCenter.default.publisher(for: .expenseDataChanged)) { _ in
            // Add a small delay to ensure context has saved
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                fetchTotalSums()
            }
        }
    }
    
    func fetchTotalSums() {
        // Refresh context to ensure we have latest data
        context.refreshAllObjects()
        
        // Get the current user (default "You" user or first user)
        let users = User.fetchAll(context: self.context)
        guard let currentUser = users.first(where: { $0.nameText == "You" }) ?? users.first else {
            // If no users exist, show empty state
            DispatchQueue.main.async {
                self.totalExpenses = 0
                self.categoriesSum = []
            }
            return
        }
        
        // Fetch only the user's split amounts across all expenses
        ExpenseLog.fetchUserSplitCategoriesTotalAmountSum(context: self.context, user: currentUser) { (results) in
            // Ensure UI updates happen on main thread
            DispatchQueue.main.async {
                guard !results.isEmpty else {
                    self.totalExpenses = 0
                    self.categoriesSum = []
                    return
                }
                
                let totalSum = results.map { $0.sum }.reduce(0, +)
                self.totalExpenses = totalSum
                self.categoriesSum = results.map({ (result) -> CategorySum in
                    return CategorySum(sum: result.sum, category: result.category)
                })
            }
        }
    }
}


struct CategorySum: Identifiable, Equatable {
    let sum: Double
    let category: Category
    
    var id: String { "\(category)\(sum)" }
}


struct DashboardTabView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardTabView()
    }
}
