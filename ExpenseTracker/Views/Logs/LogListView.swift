//
//  LogListView.swift
//  ExpenseTracker
//
// Created by Group Cluster
//

import SwiftUI
import CoreData

// Helper ViewModifier for swipe actions with iOS version compatibility
struct SwipeActionsModifier: ViewModifier {
    let onDelete: () -> Void
    let onClearSplit: (() -> Void)?
    
    func body(content: Content) -> some View {
        if #available(iOS 15.0, *) {
            content
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive, action: onDelete) {
                        if #available(iOS 14.0, *) {
                            Label("Delete", systemImage: "trash")
                        } else {
                            HStack {
                                Image(systemName: "trash")
                                Text("Delete")
                            }
                        }
                    }
                    
                    if let onClearSplit = onClearSplit {
                        Button(action: onClearSplit) {
                            if #available(iOS 14.0, *) {
                                Label("Clear Split", systemImage: "arrow.uturn.backward")
                            } else {
                                HStack {
                                    Image(systemName: "arrow.uturn.backward")
                                    Text("Clear Split")
                                }
                            }
                        }
                        .tint(.orange)
                    }
                }
        } else {
            content
        }
    }
}

struct LogListView: View {
    
    @State var logToEdit: ExpenseLog?
    
    @Environment(\.managedObjectContext)
    var context: NSManagedObjectContext
    
    @FetchRequest(
        entity: ExpenseLog.entity(),
        sortDescriptors: [
            NSSortDescriptor(keyPath: \ExpenseLog.date, ascending: false)
        ]
    )
    private var result: FetchedResults<ExpenseLog>
    
    init(predicate: NSPredicate?, sortDescriptor: NSSortDescriptor) {
        let fetchRequest = NSFetchRequest<ExpenseLog>(entityName: ExpenseLog.entity().name ?? "ExpenseLog")
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        if let predicate = predicate {
            fetchRequest.predicate = predicate
        }
        _result = FetchRequest(fetchRequest: fetchRequest)
    }
    
    var body: some View {
        List {
            ForEach(result) { (log: ExpenseLog) in
                Button(action: {
                    self.logToEdit = log
                }) {
                    HStack(spacing: 16) {
                        CategoryImageView(category: log.categoryEnum)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(log.nameText).font(.headline)
                            Text(log.dateText).font(.subheadline)
                        }
                        Spacer()
                        Text(log.amountText).font(.headline)
                    }
                    .padding(.vertical, 4)
                }
                .contextMenu {
                    // Delete expense option
                    Button(action: {
                        onDeleteExpense(log: log)
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Expense")
                        }
                    }
                    
                    // Clear split option (only show if expense has participants)
                    if !log.participantsArray.isEmpty {
                        Button(action: {
                            onClearSplit(log: log)
                        }) {
                            HStack {
                                Image(systemName: "arrow.uturn.backward")
                                Text("Clear Split")
                            }
                        }
                    }
                }
                .modifier(SwipeActionsModifier(
                    onDelete: { onDeleteExpense(log: log) },
                    onClearSplit: log.participantsArray.isEmpty ? nil : { onClearSplit(log: log) }
                ))
                
            }
               
            .onDelete(perform: onDelete)
            .sheet(item: $logToEdit, onDismiss: {
                self.logToEdit = nil
            }) { (log: ExpenseLog) in
                LogFormView(
                    logToEdit: log,
                    context: self.context,
                    name: log.name ?? "",
                    amount: log.amount?.doubleValue ?? 0,
                    category: Category(rawValue: log.category ?? "") ?? .food,
                    date: log.date ?? Date()
                )
            }
        }
    }
    
    private func onDelete(with indexSet: IndexSet) {
        indexSet.forEach { index in
            let log = result[index]
            log.deleteExpense(context: context)
        }
        try? context.saveContext()
        // Post notification to refresh dashboard
        NotificationCenter.default.post(name: .expenseDataChanged, object: nil)
    }
    
    private func onDeleteExpense(log: ExpenseLog) {
        log.deleteExpense(context: context)
        try? context.saveContext()
        // Post notification to refresh dashboard
        NotificationCenter.default.post(name: .expenseDataChanged, object: nil)
    }
    
    private func onClearSplit(log: ExpenseLog) {
        log.clearSplit(context: context)
        try? context.saveContext()
        // Post notification to refresh dashboard
        NotificationCenter.default.post(name: .expenseDataChanged, object: nil)
    }
}

struct LogListView_Previews: PreviewProvider {
    static var previews: some View {
        let stack = CoreDataStack(containerName: "ExpenseTracker")
        let sortDescriptor = ExpenseLogSort(sortType: .date, sortOrder: .descending).sortDescriptor
        return LogListView(predicate: nil, sortDescriptor: sortDescriptor)
            .environment(\.managedObjectContext, stack.viewContext)
    }
}

