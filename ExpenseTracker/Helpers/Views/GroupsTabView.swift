import SwiftUI

struct GroupsTabView: View {
    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                contentView
                    .applyNavigationTitle("Groups")
            }
        } else {
            // Fallback on earlier versions
            NavigationView {
                contentView
                    .applyNavigationTitle("Groups")
            }
        }
    }
    
    private var contentView: some View {
        Text("Groups")
    }
}

private extension View {
    @ViewBuilder
    func applyNavigationTitle(_ title: String) -> some View {
        if #available(iOS 14.0, *) {
            self.navigationTitle(title)
        } else {
            self
        }
    }
}

#Preview {
    GroupsTabView()
}
