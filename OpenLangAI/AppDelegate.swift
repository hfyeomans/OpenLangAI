import SwiftUI

@main
struct OpenLangAI: App {
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    
    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView(isOnboardingComplete: $hasCompletedOnboarding)
            }
        }
    }
}
