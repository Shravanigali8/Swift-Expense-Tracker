//
//  GroupDetailView.swift
//  ExpenseTracker
//

import SwiftUI
import CoreData
import Combine

// Helper ViewModifier for swipe actions with iOS version compatibility
struct GroupSwipeActionsModifier: ViewModifier {
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

struct GroupDetailView: View {
    
    @ObservedObject var group: Group
    @Environment(\.managedObjectContext) var context
    
    @State private var isEditFormPresented: Bool = false
    @State private var isAddExpensePresented: Bool = false
    @State private var showDebts: Bool = false
    @State private var refreshTrigger = UUID()
    
    // Computed property that forces refresh when trigger changes
    private var groupTotalExpenses: Double {
        _ = refreshTrigger // Access to trigger recomputation
        return group.totalExpenses
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Summary Section
            VStack(spacing: 16) {
                Text("Total Expenses")
                    .font(.headline)
                Text(groupTotalExpenses.formattedCurrencyText)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Button(action: { showDebts.toggle() }) {
                    HStack {
                        Text(showDebts ? "Show Expenses" : "Show Balances")
                        Image(systemName: showDebts ? "list.bullet" : "dollarsign.circle")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            
            Divider()
            
            if showDebts {
                DebtsListView(group: group)
            } else {
                GroupExpensesListView(group: group)
            }
        }
        .navigationBarTitle(group.nameText)
        .navigationBarItems(trailing: HStack {
            Button(action: { isAddExpensePresented = true }) {
                Image(systemName: "plus")
            }
            Button(action: { isEditFormPresented = true }) {
                Image(systemName: "pencil")
            }
        })
        .sheet(isPresented: $isEditFormPresented) {
            GroupFormView(groupToEdit: group, context: context)
        }
        .sheet(isPresented: $isAddExpensePresented) {
            LogFormView(context: context, group: group)
        }
        .onReceive(NotificationCenter.default.publisher(for: .expenseDataChanged)) { _ in
            // Refresh context and force view update when expenses change
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                context.refreshAllObjects()
                // Force refresh by updating refreshTrigger which triggers view update
                refreshTrigger = UUID()
                // Also trigger objectWillChange to update @ObservedObject
                group.objectWillChange.send()
            }
        }
    }
}

struct GroupExpensesListView: View {
    @ObservedObject var group: Group
    @Environment(\.managedObjectContext) var context
    
    @FetchRequest var expenses: FetchedResults<ExpenseLog>
    
    init(group: Group) {
        self.group = group
        let request: NSFetchRequest<ExpenseLog> = ExpenseLog.fetchRequest()
        request.predicate = NSPredicate(format: "group == %@", group)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ExpenseLog.date, ascending: false)]
        _expenses = FetchRequest(fetchRequest: request)
    }
    
    var body: some View {
        List {
            ForEach(expenses) { expense in
                NavigationLink(destination: ExpenseDetailView(expense: expense)) {
                    GroupExpenseRowView(expense: expense)
                }
                .contextMenu {
                    // Delete expense option
                    Button(action: {
                        deleteExpense(expense: expense)
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Expense")
                        }
                    }
                    
                    // Clear split option (only show if expense has participants)
                    if !expense.participantsArray.isEmpty {
                        Button(action: {
                            clearSplit(expense: expense)
                        }) {
                            HStack {
                                Image(systemName: "arrow.uturn.backward")
                                Text("Clear Split")
                            }
                        }
                    }
                }
                .modifier(GroupSwipeActionsModifier(
                    onDelete: { deleteExpense(expense: expense) },
                    onClearSplit: expense.participantsArray.isEmpty ? nil : { clearSplit(expense: expense) }
                ))
            }
            .onDelete(perform: deleteExpenses)
        }
    }
    
    func deleteExpense(expense: ExpenseLog) {
        expense.deleteExpense(context: context)
        try? context.saveContext()
        // Post notification to refresh dashboard
        NotificationCenter.default.post(name: .expenseDataChanged, object: nil)
    }
    
    func clearSplit(expense: ExpenseLog) {
        expense.clearSplit(context: context)
        try? context.saveContext()
        // Post notification to refresh dashboard
        NotificationCenter.default.post(name: .expenseDataChanged, object: nil)
    }
    
    func deleteExpenses(at offsets: IndexSet) {
        offsets.forEach { index in
            deleteExpense(expense: expenses[index])
        }
    }
}

struct GroupExpenseRowView: View {
    let expense: ExpenseLog
    
    var splitInfo: String {
        let participantCount = expense.participantsArray.count
        guard participantCount > 0 else { return "" }
        
        let totalAmount = expense.amount?.doubleValue ?? 0
        let perPerson = totalAmount / Double(participantCount)
        
        if participantCount == 1 {
            return "1 person"
        } else {
            return "\(participantCount) people • \(perPerson.formattedCurrencyText) each"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            CategoryImageView(category: expense.categoryEnum)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.nameText)
                    .font(.headline)
                HStack {
                    if let paidBy = expense.paidByUser {
                        Text("Paid by \(paidBy.nameText)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text(expense.dateText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if !splitInfo.isEmpty {
                    Text(splitInfo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(expense.amountText)
                    .font(.headline)
                // Validate split totals match
                let participantsTotal = expense.participantsTotal
                let expenseTotal = expense.amount?.doubleValue ?? 0
                if abs(participantsTotal - expenseTotal) > 0.01 && expense.participantsArray.count > 0 {
                    Text("⚠️ Split mismatch")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ExpenseDetailView: View {
    @ObservedObject var expense: ExpenseLog
    @Environment(\.managedObjectContext) var context
    @Environment(\.presentationMode) var presentationMode
    @State private var isEditPresented: Bool = false
    @State private var showDeleteAlert: Bool = false
    @State private var showClearSplitAlert: Bool = false
    
    var body: some View {
        List {
            Section(header: Text("Details")) {
                HStack {
                    Text("Amount")
                    Spacer()
                    Text(expense.amountText)
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Category")
                    Spacer()
                    Text(expense.categoryEnum.rawValue.capitalized)
                }
                
                HStack {
                    Text("Date")
                    Spacer()
                    Text(expense.dateText)
                }
                
                if let paidBy = expense.paidByUser {
                    HStack {
                        Text("Paid By")
                        Spacer()
                        Text(paidBy.nameText)
                    }
                }
            }
            
            if !expense.participantsArray.isEmpty {
                Section(header: Text("Split Among")) {
                    // Get current user to check settlements
                    let users = User.fetchAll(context: context)
                    let currentUser = users.first(where: { $0.nameText == "You" }) ?? users.first
                    
                    ForEach(expense.participantsArray) { participant in
                        // Check if this participant's debt is settled
                        let isSettled = checkIfParticipantDebtIsSettled(participant: participant, expense: expense, currentUser: currentUser)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(participant.user?.nameText ?? "Unknown")
                                    if isSettled {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                    }
                                }
                                if let user = participant.user, user == expense.paidByUser {
                                    Text("(Paid)")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                } else if isSettled {
                                    Text("Settled ✓")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                } else {
                                    Text("Pending")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(participant.amountValue.formattedCurrencyText)
                                    .fontWeight(.semibold)
                                    .foregroundColor(isSettled ? .secondary : .primary)
                                let totalAmount = expense.amount?.doubleValue ?? 0
                                if totalAmount > 0 {
                                    let percentage = (participant.amountValue / totalAmount) * 100
                                    Text("\(percentage.rounded(toPlaces: 1))%")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .opacity(isSettled ? 0.6 : 1.0)
                    }
                    
                    // Show split summary
                    let participantsTotal = expense.participantsTotal
                    let expenseTotal = expense.amount?.doubleValue ?? 0
                    HStack {
                        Text("Total Split:")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(participantsTotal.formattedCurrencyText)
                            .foregroundColor(abs(participantsTotal - expenseTotal) < 0.01 ? .green : .red)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .navigationBarTitle(expense.nameText)
        .navigationBarItems(trailing: HStack(spacing: 16) {
            // Clear Split button (only show if expense has participants)
            if !expense.participantsArray.isEmpty {
                Button(action: {
                    showClearSplitAlert = true
                }) {
                    Image(systemName: "arrow.uturn.backward")
                }
            }
            
            // Delete Expense button
            Button(action: {
                showDeleteAlert = true
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            
            // Edit button
            Button("Edit") {
                isEditPresented = true
            }
        })
        .sheet(isPresented: $isEditPresented) {
            LogFormView(
                logToEdit: expense,
                context: context,
                group: expense.groupExpense
            )
        }
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("Delete Expense"),
                message: Text("Are you sure you want to delete this expense? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    deleteExpense()
                },
                secondaryButton: .cancel()
            )
        }
        .alert(isPresented: $showClearSplitAlert) {
            Alert(
                title: Text("Clear Split"),
                message: Text("Are you sure you want to clear the split for this expense? This will remove all participants."),
                primaryButton: .default(Text("Clear Split")) {
                    clearSplit()
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    func deleteExpense() {
        expense.deleteExpense(context: context)
        try? context.saveContext()
        // Post notification to refresh dashboard and groups
        NotificationCenter.default.post(name: .expenseDataChanged, object: nil)
        // Dismiss the view
        presentationMode.wrappedValue.dismiss()
    }
    
    func clearSplit() {
        expense.clearSplit(context: context)
        try? context.saveContext()
        // Post notification to refresh dashboard and groups
        NotificationCenter.default.post(name: .expenseDataChanged, object: nil)
    }
    
    // Check if a participant's debt is settled (only for "YOU")
    func checkIfParticipantDebtIsSettled(participant: ExpenseParticipant, expense: ExpenseLog, currentUser: User?) -> Bool {
        guard let participantUser = participant.user,
              let paidBy = expense.paidByUser,
              let group = expense.group,
              let currentUser = currentUser else {
            return false
        }
        
        // Only show settlement status if "YOU" is involved in this split
        let isYouInvolved = participantUser == currentUser || paidBy == currentUser
        guard isYouInvolved else {
            return false
        }
        
        // Fetch all settled debts for this group
        let allDebts = Debt.fetchAll(context: context, group: group, includeSettled: true)
        let settledDebts = allDebts.filter { $0.isSettled }
        
        // Check if there's a settled debt involving the current user and this participant
        // Case 1: "YOU" owe this participant (participant paid, YOU owe them)
        if paidBy == participantUser && participantUser != currentUser {
            // Check if there's a settled debt where YOU owe this participant
            return settledDebts.contains { debt in
                debt.owedBy == currentUser &&
                debt.owedTo == participantUser
            }
        }
        // Case 2: Participant owes "YOU" (YOU paid, they owe YOU)
        else if paidBy == currentUser && participantUser != currentUser {
            // Check if there's a settled debt where this participant owes YOU
            return settledDebts.contains { debt in
                debt.owedBy == participantUser &&
                debt.owedTo == currentUser
            }
        }
        
        return false
    }
}

struct DebtsListView: View {
    @ObservedObject var group: Group
    @Environment(\.managedObjectContext) var context
    
    @State private var debts: [Debt] = []
    
    var body: some View {
        List {
            if debts.isEmpty {
                Text("All settled up! 🎉")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(debts) { debt in
                    DebtRowView(debt: debt, onSettled: {
                        loadDebts()
                    })
                }
            }
        }
        .onAppear(perform: loadDebts)
        .onReceive(NotificationCenter.default.publisher(for: .expenseDataChanged)) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                loadDebts()
            }
        }
    }
    
    func loadDebts() {
        // Get the current user ("YOU")
        let users = User.fetchAll(context: context)
        guard let currentUser = users.first(where: { $0.nameText == "You" }) ?? users.first else {
            debts = []
            return
        }
        
        // Fetch all debts for the group
        let allDebts = Debt.fetchAll(context: context, group: group, includeSettled: false)
        
        // Filter to only show debts involving "YOU"
        debts = allDebts.filter { debt in
            guard let owedBy = debt.owedBy, let owedTo = debt.owedTo else { return false }
            return owedBy == currentUser || owedTo == currentUser
        }
    }
}

struct DebtRowView: View {
    let debt: Debt
    var onSettled: (() -> Void)? = nil
    @Environment(\.managedObjectContext) var context
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("\(debt.owedBy?.nameText ?? "Unknown") owes")
                    .font(.headline)
                Text(debt.owedTo?.nameText ?? "Unknown")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(debt.amountValue.formattedCurrencyText)
                    .font(.headline)
                    .foregroundColor(.red)
                
                Button("Settle Up") {
                    settleDebt()
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
    }
    
    func settleDebt() {
        debt.settle()
        do {
            try context.saveContext()
            // Post notification to refresh all views
            NotificationCenter.default.post(name: .expenseDataChanged, object: nil)
            onSettled?()
        } catch {
            print("Error settling debt: \(error.localizedDescription)")
        }
    }
}

struct GroupDetailView_Previews: PreviewProvider {
    static var previews: some View {
        GroupDetailView(group: Group())
    }
}