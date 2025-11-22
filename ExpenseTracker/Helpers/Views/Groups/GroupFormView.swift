//
//  GroupFormView.swift
//  ExpenseTracker
//
//  Created by ExpenseTracker on 2024.
//

import SwiftUI
import CoreData

struct GroupFormView: View {
    
    var groupToEdit: Group?
    var context: NSManagedObjectContext
    
    @State private var name: String = ""
    @State private var selectedMembers: Set<User> = Set()
    @State private var availableUsers: [User] = []
    @State private var newUserName: String = ""
    
    @Environment(\.presentationMode)
    var presentationMode
    
    var title: String {
        groupToEdit == nil ? "Create Group" : "Edit Group"
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Group Name")) {
                    TextField("Group Name", text: $name)
                        .disableAutocorrection(true)
                }
                
                Section(header: Text("Members")) {
                    ForEach(availableUsers) { user in
                        HStack {
                            Text(user.nameText)
                            Spacer()
                            if selectedMembers.contains(user) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedMembers.contains(user) {
                                selectedMembers.remove(user)
                            } else {
                                selectedMembers.insert(user)
                            }
                        }
                    }
                    
                    HStack {
                        TextField("New member name", text: $newUserName)
                            .disableAutocorrection(true)
                        Button("Add") {
                            addNewUser()
                        }
                        .disabled(newUserName.isEmpty)
                    }
                }
            }
            .navigationBarTitle(title)
            .navigationBarItems(
                leading: Button("Cancel") { presentationMode.wrappedValue.dismiss() },
                trailing: Button("Save") { onSaveTapped() }
                    .disabled(name.isEmpty || selectedMembers.isEmpty)
            )
            .onAppear(perform: loadData)
        }
    }
    
    func loadData() {
        availableUsers = User.fetchAll(context: context)
        
        if let group = groupToEdit {
            name = group.nameText
            selectedMembers = Set(group.membersArray)
        } else {
            // Create default "You" user if none exists
            if availableUsers.isEmpty {
                let defaultUser = User.createDefaultUser(context: context)
                try? context.saveContext()
                availableUsers = User.fetchAll(context: context)
            }
        }
    }
    
    func addNewUser() {
        guard !newUserName.isEmpty else { return }
        
        let user = User.findOrCreate(context: context, name: newUserName)
        try? context.saveContext()
        availableUsers = User.fetchAll(context: context)
        selectedMembers.insert(user)
        newUserName = ""
    }
    
    func onSaveTapped() {
        let group: Group
        if let groupToEdit = self.groupToEdit {
            group = groupToEdit
        } else {
            group = Group.create(context: context, name: name, members: [])
            group.id = UUID()
        }
        
        group.name = name
        group.members = NSSet(array: Array(selectedMembers))
        
        do {
            try context.saveContext()
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Error saving group: \(error.localizedDescription)")
        }
    }
}

struct GroupFormView_Previews: PreviewProvider {
    static var previews: some View {
        let stack = CoreDataStack(containerName: "ExpenseTracker")
        return GroupFormView(context: stack.viewContext)
    }
}

