import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            SessionView()
                .tabItem {
                    Label("Practice", systemImage: "mic.fill")
                }
                .tag(0)
            
            Text("Review")
                .tabItem {
                    Label("Review", systemImage: "book.fill")
                }
                .tag(1)
            
            ContentView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}