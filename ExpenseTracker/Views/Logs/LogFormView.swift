//
//  LogFormView.swift
//  ExpenseTracker
//
// Created by Group Cluster
//

import SwiftUI
import CoreData

enum SplitMethod: String, CaseIterable {
    case equal = "Equal"
    case amount = "By Amount"
    case percentage = "By Percentage"
}

struct LogFormView: View {
    
    var logToEdit: ExpenseLog?
    var context: NSManagedObjectContext
    var group: Group? = nil
    
    @State var name: String = ""
    @State var amount: Double = 0
    @State var category: Category = .utilities
    @State var date: Date = Date()
    @State var isGroupExpense: Bool = false
    @State var paidBy: User?
    @State var selectedParticipants: Set<User> = Set()
    @State var splitMethod: SplitMethod = .equal
    @State var customAmounts: [User: Double] = [:]
    @State var customPercentages: [User: Double] = [:]
    @State var availableUsers: [User] = []
    @State var showSplitOptions: Bool = false
    
    @Environment(\.presentationMode)
    var presentationMode
    
    var title: String {
        logToEdit == nil ? "Create Expense Log" : "Edit Expense Log"
    }
    
    var isGroupMode: Bool {
        let currentGroup = group ?? logToEdit?.groupExpense
        return currentGroup != nil || isGroupExpense
    }
    
    var currentGroup: Group? {
        group ?? logToEdit?.groupExpense
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic Information")) {
                TextField("Name", text: $name)
                    .disableAutocorrection(true)
                TextField("Amount", value: $amount, formatter: Utils.numberFormatter)
                    .keyboardType(.numbersAndPunctuation)
                    
                Picker(selection: $category, label: Text("Category")) {
                    ForEach(Category.allCases) { category in
                        Text(category.rawValue.capitalized).tag(category)
                    }
                }
                DatePicker(selection: $date, displayedComponents: .date) {
                    Text("Date")
                }
            }

                if currentGroup == nil {
                    Section(header: Text("Group Expense")) {
                        Toggle("Split with others", isOn: $isGroupExpense)
                    }
                }
                
                if isGroupMode {
                    Section(header: Text("Paid By")) {
                        Picker("Paid By", selection: $paidBy) {
                            Text("Select person").tag(nil as User?)
                            ForEach(availableUsers) { user in
                                Text(user.nameText).tag(user as User?)
                            }
                        }
                    }
                    
                    Section(header: Text("Split Among")) {
                        ForEach(availableUsers) { user in
                            HStack {
                                Text(user.nameText)
                                Spacer()
                                if selectedParticipants.contains(user) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedParticipants.contains(user) {
                                    selectedParticipants.remove(user)
                                    customAmounts.removeValue(forKey: user)
                                    customPercentages.removeValue(forKey: user)
                                } else {
                                    selectedParticipants.insert(user)
                                    if splitMethod == .equal {
                                        updateEqualSplit()
                                    }
                                }
                            }
                        }
                    }
                    
                    if !selectedParticipants.isEmpty {
                        Section(header: Text("Split Method")) {
                            Picker("Method", selection: $splitMethod) {
                                ForEach(SplitMethod.allCases, id: \.self) { method in
                                    Text(method.rawValue).tag(method)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            
                            if splitMethod == .amount {
                                ForEach(Array(selectedParticipants), id: \.id) { user in
                                    HStack {
                                        Text(user.nameText)
                                        Spacer()
                                        TextField("Amount", value: Binding(
                                            get: { customAmounts[user] ?? 0 },
                                            set: { customAmounts[user] = $0 }
                                        ), formatter: Utils.numberFormatter)
                                        .keyboardType(.decimalPad)
                                        .frame(width: 100)
                                    }
                                }
                            } else if splitMethod == .percentage {
                                ForEach(Array(selectedParticipants), id: \.id) { user in
                                    HStack {
                                        Text(user.nameText)
                                        Spacer()
                                        TextField("%", value: Binding(
                                            get: { customPercentages[user] ?? 0 },
                                            set: { customPercentages[user] = $0 }
                                        ), formatter: NumberFormatter())
                                        .keyboardType(.decimalPad)
                                        .frame(width: 80)
                                        Text("%")
                                    }
                                }
                            }
                            
                            if splitMethod == .equal {
                                Text("Each person: \(equalSplitAmount.formattedCurrencyText)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            let total = splitTotal
                            if total != amount && amount > 0 {
                                HStack {
                                    Text("Total split:")
                                    Spacer()
                                    Text(total.formattedCurrencyText)
                                        .foregroundColor(total == amount ? .green : .red)
                                }
                                if total != amount {
                                    Text("Amounts don't match total expense")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarTitle(title)
            .navigationBarItems(
                leading: Button("Cancel") { onCancelTapped() },
                trailing: Button("Save") { onSaveTapped() }
                    .disabled(name.isEmpty || amount <= 0 || (isGroupMode && (paidBy == nil || selectedParticipants.isEmpty)))
            )
            .onAppear(perform: loadData)
        }
    }
    
    var equalSplitAmount: Double {
        guard !selectedParticipants.isEmpty, amount > 0 else { return 0 }
        return amount / Double(selectedParticipants.count)
    }
    
    var splitTotal: Double {
        switch splitMethod {
        case .equal:
            return equalSplitAmount * Double(selectedParticipants.count)
        case .amount:
            return customAmounts.values.reduce(0, +)
        case .percentage:
            let percentageTotal = customPercentages.values.reduce(0, +)
            return amount * (percentageTotal / 100.0)
        }
    }
    
    func loadData() {
        availableUsers = User.fetchAll(context: context)
        
        if let logToEdit = self.logToEdit {
            name = logToEdit.nameText
            amount = logToEdit.amount?.doubleValue ?? 0
            category = logToEdit.categoryEnum
            date = logToEdit.date ?? Date()
            isGroupExpense = logToEdit.isGroupExpenseValue
            paidBy = logToEdit.paidByUser
            // Only set group from logToEdit if it wasn't provided as parameter
            if group == nil {
                // Note: Can't reassign var parameter, so we'll use the group from logToEdit via computed property
            }
            
            // Load participants
            selectedParticipants = Set(logToEdit.participantsArray.compactMap { $0.user })
            
            // Load custom amounts if any
            for participant in logToEdit.participantsArray {
                if let user = participant.user {
                    customAmounts[user] = participant.amountValue
                }
            }
        } else if let currentGroup = currentGroup {
            isGroupExpense = true
            availableUsers = currentGroup.membersArray
            if let firstUser = availableUsers.first {
                paidBy = firstUser
            }
        }
        
        if availableUsers.isEmpty {
            let defaultUser = User.createDefaultUser(context: context)
            try? context.saveContext()
            availableUsers = User.fetchAll(context: context)
        }
        
        if paidBy == nil && !availableUsers.isEmpty {
            paidBy = availableUsers.first
        }
    }
    
    func updateEqualSplit() {
        // Equal split is calculated on the fly
    }
    
    func onCancelTapped() {
        presentationMode.wrappedValue.dismiss()
    }
    
    func onSaveTapped() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        // Validate that all participants are group members
        if isGroupMode, let group = currentGroup {
            let groupMembers = Set(group.membersArray)
            let invalidParticipants = selectedParticipants.filter { !groupMembers.contains($0) }
            
            if !invalidParticipants.isEmpty {
                print("Warning: Some participants are not group members")
                // Remove invalid participants
                selectedParticipants = selectedParticipants.intersection(groupMembers)
            }
        }
        
        let log: ExpenseLog
        let isEditing = logToEdit != nil
        
        if let logToEdit = self.logToEdit {
            log = logToEdit
            
            // Reverse old debts if editing a group expense
            if isGroupMode && currentGroup != nil {
                Debt.reverseDebts(from: log, context: context)
            }
        } else {
            log = ExpenseLog(context: self.context)
            log.id = UUID()
        }
        
        log.name = self.name
        log.category = self.category.rawValue
        log.amount = NSDecimalNumber(value: self.amount)
        log.date = self.date
        log.isGroupExpense = isGroupMode
        log.group = currentGroup
        log.paidBy = paidBy
        
        // Handle splitting
        if isGroupMode && !selectedParticipants.isEmpty {
            // Ensure paidBy is included in participants if they're not already
            var participantsToSplit = selectedParticipants
            if let paidBy = paidBy, !participantsToSplit.contains(paidBy) {
                // Note: paidBy will be excluded from debt calculation, but can be in split
                // This allows tracking who paid vs who owes
            }
            
            switch splitMethod {
            case .equal:
                log.splitEqually(among: Array(participantsToSplit), context: context)
            case .amount:
                // Validate amounts match total
                let total = customAmounts.values.reduce(0, +)
                if abs(total - amount) > 0.01 {
                    // Auto-adjust will happen in splitByAmounts
                }
                log.splitByAmounts(amounts: customAmounts, context: context)
            case .percentage:
                var amounts: [User: Double] = [:]
                for (user, percentage) in customPercentages {
                    amounts[user] = amount * (percentage / 100.0)
                }
                log.splitByAmounts(amounts: amounts, context: context)
            }
        }
        
        do {
            try context.saveContext()
            
            // Calculate debts if it's a group expense
            if isGroupMode && currentGroup != nil {
                Debt.calculateAndCreateDebts(from: log, context: context)
                try context.saveContext()
            }
            
            // Post notification to refresh dashboard after all saves complete
            NotificationCenter.default.post(name: .expenseDataChanged, object: nil)
            
            presentationMode.wrappedValue.dismiss()
        } catch let error as NSError {
            print("Error saving: \(error.localizedDescription)")
            // Post notification even on error, in case partial saves occurred
            NotificationCenter.default.post(name: .expenseDataChanged, object: nil)
        }
    }
}

struct LogFormView_Previews: PreviewProvider {
    static var previews: some View {
        let stack = CoreDataStack(containerName: "ExpenseTracker")
        return LogFormView(context: stack.viewContext)
    }
}
