import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = Constants.TabTags.practice
    
    var body: some View {
        TabView(selection: $selectedTab) {
            SessionView()
                .tabItem {
                    Label(Constants.Text.Tabs.practice, systemImage: Constants.SFSymbols.micFill)
                }
                .tag(Constants.TabTags.practice)
            
            Text(Constants.Text.Tabs.review)
                .tabItem {
                    Label(Constants.Text.Tabs.review, systemImage: Constants.SFSymbols.bookFill)
                }
                .tag(Constants.TabTags.review)
            
            ContentView()
                .tabItem {
                    Label(Constants.Text.Tabs.settings, systemImage: Constants.SFSymbols.gear)
                }
                .tag(Constants.TabTags.settings)
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
    }
}