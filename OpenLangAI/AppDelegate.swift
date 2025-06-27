import SwiftUI
import SecureStoreKit

@main
struct OpenLangAI: App {
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    
    init() {
        // Migrate legacy API keys to provider-specific format
        KeychainHelper.migrateLegacyKeysIfNeeded()
    }
    
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
