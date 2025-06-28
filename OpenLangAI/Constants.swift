import Foundation
import SwiftUI

// MARK: - Constants

enum Constants {
    
    // MARK: - UserDefaults Keys
    
    enum UserDefaultsKeys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let selectedLanguage = "selectedLanguage"
        static let userLevel = "userLevel"
    }
    
    // MARK: - Notification Names
    
    enum Notifications {
        static let onboardingCompleted = Notification.Name("onboardingCompleted")
    }
    
    // MARK: - Core Data
    
    enum CoreData {
        static let containerName = "OpenLangAI"
        
        enum EntityNames {
            static let conversation = "Conversation"
            static let message = "Message"
        }
    }
    
    // MARK: - SF Symbols
    
    enum SFSymbols {
        // Navigation
        static let chevronRight = "chevron.right"
        static let chevronLeft = "chevron.left"
        
        // Actions
        static let clipboard = "doc.on.clipboard"
        static let checkmark = "checkmark.circle.fill"
        static let exclamation = "exclamationmark.triangle.fill"
        
        // Audio
        static let micFill = "mic.fill"
        static let pauseFill = "pause.fill"
        static let speakerWave = "speaker.wave.2.fill"
        
        // Tab Icons
        static let bookFill = "book.fill"
        static let clockFill = "clock.fill"
        static let gear = "gear"
        
        // Other
        static let messageFill = "message.fill"
        static let bellBadge = "bell.badge"
    }
    
    // MARK: - UI Text
    
    enum Text {
        
        // MARK: Onboarding
        enum Onboarding {
            static let chooseLanguageTitle = "Choose Your Target Language"
            static let chooseLanguageSubtitle = "What language would you like to practice?"
            static let chooseLevelTitle = "What's Your Level?"
            static let chooseLevelSubtitle = "This helps us tailor conversations to your needs"
            static let apiKeyTitle = "OpenAI API Key"
            static let apiKeySubtitle = "Your key is encrypted on-device and never leaves your phone"
            static let apiKeyPlaceholder = "API Key"
            static let apiKeySecureFieldPlaceholder = "sk-..."
            static let continueButton = "Continue"
            static let skipButton = "Skip for now"
            static let pasteButton = "Paste"
            static let backButton = "Back"
            static let errorTitle = "Error"
            static let okButton = "OK"
            static let genericError = "An error occurred"
            
            // Level Descriptions
            static let beginnerDescription = "I'm just starting to learn "
            static let intermediateDescription = "I can have basic conversations in "
        }
        
        // MARK: Session
        enum Session {
            static let endSession = "End Session"
            static let startNewConversation = "Start New Conversation"
            static let errorPrefix = "Failed to get AI response: "
            static let showTranslations = "Show translations"
            static let listening = "Listening..."
            static let tapToSpeak = "Tap to speak"
        }
        
        // MARK: Session Recap
        enum SessionRecap {
            static let newVocabulary = "New Vocabulary"
            static let noVocabulary = "No new vocabulary items found"
            static let scheduleDailyReview = "Schedule Daily Review"
            static let sessionSummary = "Session Summary"
            static let performance = "Performance"
            static let confidence = "Confidence"
            static let minuteSuffix = " min"
            static let messagesSuffix = " messages"
            static let percentSuffix = "%"
        }
        
        // MARK: Settings
        enum Settings {
            static let llmProvider = "LLM Provider"
            static let apiKey = "API Key"
            static let language = "Language"
            static let testResult = "Test Result"
        }
        
        // MARK: Tab Names
        enum Tabs {
            static let practice = "Practice"
            static let review = "Review"
            static let settings = "Settings"
        }
        
        // MARK: Validation Messages
        enum Validation {
            static let apiKeySuccess = "Success! API key validated"
            static let apiKeyFailure = "Invalid API key"
            static let permissionDenied = "Permission denied"
        }
    }
    
    // MARK: - Animation Durations
    
    enum AnimationDurations {
        static let short: Double = 0.3
        static let medium: Double = 0.5
        static let long: Double = 1.0
        static let extraLong: Double = 1.5
        
        // Nanoseconds for Task.sleep
        static let shortNanoseconds: UInt64 = 300_000_000 // 0.3 seconds
        static let mediumNanoseconds: UInt64 = 500_000_000 // 0.5 seconds
        static let longNanoseconds: UInt64 = 1_000_000_000 // 1 second
        static let extraLongNanoseconds: UInt64 = 1_500_000_000 // 1.5 seconds
    }
    
    // MARK: - Tab View Tags
    
    enum TabTags {
        static let practice = 0
        static let review = 1
        static let settings = 2
    }
    
    // MARK: - User Levels
    
    enum UserLevels {
        static let completeBeginner = "Complete Beginner"
        static let intermediate = "Intermediate"
        
        // UserDefaults storage values
        static let beginnerKey = "beginner"
        static let intermediateKey = "intermediate"
    }
    
    // MARK: - Languages
    
    enum Languages {
        static let spanish = "Spanish"
        static let french = "French"
        static let japanese = "Japanese"
        static let italian = "Italian"
        static let portuguese = "Portuguese"
        static let english = "English"
        static let german = "German"
        static let chinese = "Chinese"
        static let korean = "Korean"
        
        // Language Codes
        static let localeIdentifiers: [String: String] = [
            spanish: "es-ES",
            french: "fr-FR",
            japanese: "ja-JP",
            italian: "it-IT",
            portuguese: "pt-BR",
            english: "en-US",
            german: "de-DE",
            chinese: "zh-CN",
            korean: "ko-KR"
        ]
    }
    
    // MARK: - API Configuration
    
    enum API {
        static let defaultTimeout: TimeInterval = 30.0
        static let maxRetries = 3
    }
    
    // MARK: - Audio Configuration
    
    enum Audio {
        static let bufferSize: UInt32 = 1024
        static let speechRate: Float = 0.5
    }
}

// MARK: - Type-Safe UserDefaults Extensions

extension UserDefaults {
    
    // MARK: Onboarding
    
    var hasCompletedOnboarding: Bool {
        get { bool(forKey: Constants.UserDefaultsKeys.hasCompletedOnboarding) }
        set { set(newValue, forKey: Constants.UserDefaultsKeys.hasCompletedOnboarding) }
    }
    
    var selectedLanguage: String? {
        get { string(forKey: Constants.UserDefaultsKeys.selectedLanguage) }
        set { set(newValue, forKey: Constants.UserDefaultsKeys.selectedLanguage) }
    }
    
    var userLevel: String? {
        get { string(forKey: Constants.UserDefaultsKeys.userLevel) }
        set { set(newValue, forKey: Constants.UserDefaultsKeys.userLevel) }
    }
}