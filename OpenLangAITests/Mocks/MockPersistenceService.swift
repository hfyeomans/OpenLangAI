import Foundation
import CoreData
import Combine
@testable import OpenLangAI
@testable import PersistenceKit

// MARK: - MockPersistenceService

class MockPersistenceService: PersistenceServiceProtocol {
    
    // MARK: - Test Control Properties
    
    var shouldFailSave = false
    var shouldFailFetch = false
    var saveCallCount = 0
    var createConversationCallCount = 0
    var addMessageCallCount = 0
    var addVocabularyCallCount = 0
    
    // Mock data storage
    private var conversations: [Conversation] = []
    private var messages: [UUID: [Message]] = [:]
    private var vocabularyItems: [UUID: [VocabularyItem]] = [:]
    private var userProgress: [String: UserProgress] = [:]
    
    // Mock Core Data context
    lazy var mockContext: NSManagedObjectContext = {
        let container = NSPersistentContainer(name: Constants.CoreData.containerName)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load mock store: \(error)")
            }
        }
        
        return container.viewContext
    }()
    
    var viewContext: NSManagedObjectContext {
        mockContext
    }
    
    // MARK: - Context Management
    
    func save() async throws {
        saveCallCount += 1
        
        if shouldFailSave {
            throw PersistenceError.saveFailed(NSError(domain: "MockError", code: 1))
        }
        
        try mockContext.save()
    }
    
    // MARK: - Conversation Operations
    
    func createConversation(language: String, userLevel: String) async throws -> Conversation {
        createConversationCallCount += 1
        
        let conversation = Conversation(context: mockContext)
        conversation.id = UUID()
        conversation.language = language
        conversation.userLevel = userLevel
        conversation.startTime = Date()
        
        conversations.append(conversation)
        messages[conversation.id] = []
        vocabularyItems[conversation.id] = []
        
        return conversation
    }
    
    func endConversation(_ conversation: Conversation) async throws {
        conversation.endTime = Date()
        try await updateUserProgress(for: conversation.language)
    }
    
    func fetchRecentConversations(limit: Int) async throws -> [Conversation] {
        if shouldFailFetch {
            throw PersistenceError.fetchFailed(NSError(domain: "MockError", code: 2))
        }
        
        let sorted = conversations.sorted { $0.startTime > $1.startTime }
        return Array(sorted.prefix(limit))
    }
    
    func fetchConversations(for language: String, limit: Int?) async throws -> [Conversation] {
        if shouldFailFetch {
            throw PersistenceError.fetchFailed(NSError(domain: "MockError", code: 2))
        }
        
        let filtered = conversations.filter { $0.language == language }
            .sorted { $0.startTime > $1.startTime }
        
        if let limit = limit {
            return Array(filtered.prefix(limit))
        }
        return filtered
    }
    
    func deleteConversation(_ conversation: Conversation) async throws {
        conversations.removeAll { $0.id == conversation.id }
        messages[conversation.id] = nil
        vocabularyItems[conversation.id] = nil
        mockContext.delete(conversation)
    }
    
    // MARK: - Message Operations
    
    func addMessage(to conversation: Conversation, text: String, isUser: Bool, translation: String?) async throws -> Message {
        addMessageCallCount += 1
        
        let message = Message(context: mockContext)
        message.id = UUID()
        message.text = text
        message.isUser = isUser
        message.translation = translation
        message.timestamp = Date()
        message.conversation = conversation
        
        messages[conversation.id]?.append(message)
        
        return message
    }
    
    func fetchMessages(for conversation: Conversation) async throws -> [Message] {
        if shouldFailFetch {
            throw PersistenceError.fetchFailed(NSError(domain: "MockError", code: 2))
        }
        
        return messages[conversation.id] ?? []
    }
    
    func updateMessageTranslation(_ message: Message, translation: String) async throws {
        message.translation = translation
    }
    
    // MARK: - User Progress Operations
    
    func fetchOrCreateUserProgress(for language: String) async throws -> UserProgress {
        if let existing = userProgress[language] {
            return existing
        }
        
        let progress = UserProgress(context: mockContext)
        progress.id = UUID()
        progress.language = language
        progress.totalSessions = 0
        progress.totalMinutesPracticed = 0
        progress.currentStreak = 0
        progress.longestStreak = 0
        
        userProgress[language] = progress
        return progress
    }
    
    func fetchAllUserProgress() async throws -> [UserProgress] {
        if shouldFailFetch {
            throw PersistenceError.fetchFailed(NSError(domain: "MockError", code: 2))
        }
        
        return Array(userProgress.values)
    }
    
    func updateUserProgress(for language: String) async throws {
        let progress = try await fetchOrCreateUserProgress(for: language)
        progress.totalSessions += 1
        progress.totalMinutesPracticed += 10 // Mock 10 minutes per session
        progress.updateStreak()
    }
    
    func resetUserProgress(for language: String) async throws {
        if let progress = userProgress[language] {
            progress.totalSessions = 0
            progress.totalMinutesPracticed = 0
            progress.currentStreak = 0
            progress.longestStreak = 0
            progress.lastSessionDate = nil
        }
    }
    
    // MARK: - Vocabulary Operations
    
    func addVocabularyItem(to conversation: Conversation, word: String, translation: String?, definition: String?) async throws -> VocabularyItem {
        addVocabularyCallCount += 1
        
        let item = VocabularyItem(context: mockContext)
        item.id = UUID()
        item.word = word
        item.translation = translation
        item.definition = definition
        item.conversation = conversation
        item.nextReviewDate = Date().addingTimeInterval(86400) // Tomorrow
        
        vocabularyItems[conversation.id]?.append(item)
        
        return item
    }
    
    func fetchVocabularyForReview(language: String) async throws -> [VocabularyItem] {
        if shouldFailFetch {
            throw PersistenceError.fetchFailed(NSError(domain: "MockError", code: 2))
        }
        
        var allVocabulary: [VocabularyItem] = []
        
        for conversation in conversations where conversation.language == language {
            if let items = vocabularyItems[conversation.id] {
                allVocabulary.append(contentsOf: items.filter { 
                    $0.nextReviewDate ?? Date() <= Date() 
                })
            }
        }
        
        return allVocabulary
    }
    
    func fetchVocabulary(for conversation: Conversation) async throws -> [VocabularyItem] {
        if shouldFailFetch {
            throw PersistenceError.fetchFailed(NSError(domain: "MockError", code: 2))
        }
        
        return vocabularyItems[conversation.id] ?? []
    }
    
    func markVocabularyAsReviewed(_ item: VocabularyItem) async throws {
        item.reviewCount += 1
        item.lastReviewedDate = Date()
    }
    
    func scheduleNextReview(for item: VocabularyItem) async throws {
        item.scheduleNextReview()
    }
    
    // MARK: - Statistics Operations
    
    func fetchTotalPracticeTime(for language: String?) async throws -> Int {
        if shouldFailFetch {
            throw PersistenceError.fetchFailed(NSError(domain: "MockError", code: 2))
        }
        
        if let language = language {
            return Int(userProgress[language]?.totalMinutesPracticed ?? 0)
        }
        
        return userProgress.values.reduce(0) { $0 + Int($1.totalMinutesPracticed) }
    }
    
    func fetchMessageCount(for language: String?) async throws -> Int {
        if shouldFailFetch {
            throw PersistenceError.fetchFailed(NSError(domain: "MockError", code: 2))
        }
        
        if let language = language {
            let conversationsForLanguage = conversations.filter { $0.language == language }
            return conversationsForLanguage.compactMap { messages[$0.id]?.count }.reduce(0, +)
        }
        
        return messages.values.reduce(0) { $0 + $1.count }
    }
    
    func fetchVocabularyCount(for language: String?) async throws -> Int {
        if shouldFailFetch {
            throw PersistenceError.fetchFailed(NSError(domain: "MockError", code: 2))
        }
        
        if let language = language {
            let conversationsForLanguage = conversations.filter { $0.language == language }
            return conversationsForLanguage.compactMap { vocabularyItems[$0.id]?.count }.reduce(0, +)
        }
        
        return vocabularyItems.values.reduce(0) { $0 + $1.count }
    }
    
    func fetchCurrentStreak(for language: String) async throws -> Int {
        if shouldFailFetch {
            throw PersistenceError.fetchFailed(NSError(domain: "MockError", code: 2))
        }
        
        return Int(userProgress[language]?.currentStreak ?? 0)
    }
    
    // MARK: - Test Helper Methods
    
    func reset() {
        shouldFailSave = false
        shouldFailFetch = false
        saveCallCount = 0
        createConversationCallCount = 0
        addMessageCallCount = 0
        addVocabularyCallCount = 0
        
        conversations.removeAll()
        messages.removeAll()
        vocabularyItems.removeAll()
        userProgress.removeAll()
    }
    
    func injectMockConversation(language: String, userLevel: String, messageCount: Int = 5) -> Conversation {
        let conversation = Conversation(context: mockContext)
        conversation.id = UUID()
        conversation.language = language
        conversation.userLevel = userLevel
        conversation.startTime = Date().addingTimeInterval(-3600) // 1 hour ago
        
        conversations.append(conversation)
        messages[conversation.id] = []
        
        // Add mock messages
        for i in 0..<messageCount {
            let message = Message(context: mockContext)
            message.id = UUID()
            message.text = "Test message \(i)"
            message.isUser = i % 2 == 0
            message.timestamp = Date().addingTimeInterval(Double(i * 60))
            message.conversation = conversation
            messages[conversation.id]?.append(message)
        }
        
        return conversation
    }
}