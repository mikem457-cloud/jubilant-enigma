import SwiftUI
import DesignSystem

struct RootView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
            PetsView()
                .tabItem { Label("Pets", systemImage: "pawprint.fill") }
            RecordsView()
                .tabItem { Label("Records", systemImage: "doc.text.fill") }
            MoreView()
                .tabItem { Label("More", systemImage: "ellipsis.circle.fill") }
        }
        .tint(.fsBrandNavy)
    }
}

#Preview {
    RootView()
}
