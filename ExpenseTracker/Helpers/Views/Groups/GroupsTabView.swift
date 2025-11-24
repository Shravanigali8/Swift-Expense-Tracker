//
//  GroupsTabView.swift
//  ExpenseTracker
//



import SwiftUI
import CoreData
import Combine

struct GroupsTabView: View {
    
    @Environment(\.managedObjectContext)
    var context: NSManagedObjectContext
    
    @State private var isAddFormPresented: Bool = false
    @State private var selectedGroup: Group?
    
    @FetchRequest(
        entity: Group.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Group.createdAt, ascending: false)]
    )
    private var groups: FetchedResults<Group>
    
    var body: some View {
        NavigationView {
            List {
                ForEach(groups) { group in
                    NavigationLink(destination: GroupDetailView(group: group)) {
                        GroupRowView(group: group)
                    }
                }
                .onDelete(perform: deleteGroups)
            }
            .navigationBarTitle("Groups")
            .navigationBarItems(trailing: Button(action: addTapped) { Text("Add") })
            .sheet(isPresented: $isAddFormPresented) {
                GroupFormView(context: self.context)
            }
            .onReceive(NotificationCenter.default.publisher(for: .expenseDataChanged)) { _ in
                // Refresh context when expenses change to update group totals
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    context.refreshAllObjects()
                }
            }
        }
    }
    
    func addTapped() {
        isAddFormPresented = true
    }
    
    func deleteGroups(at offsets: IndexSet) {
        offsets.forEach { index in
            context.delete(groups[index])
        }
        try? context.saveContext()
    }
}

struct GroupRowView: View {
    let group: Group
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.nameText)
                .font(.headline)
            HStack {
                Text("\(group.membersArray.count) members")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(group.totalExpenses.formattedCurrencyText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct GroupsTabView_Previews: PreviewProvider {
    static var previews: some View {
        GroupsTabView()
    }
}