import Foundation
import CoreData
import Combine
import PersistenceKit

// MARK: - PersistenceService Protocol

@MainActor
protocol PersistenceServiceProtocol: AnyObject {
    // Context Management
    func save() async throws
    var viewContext: NSManagedObjectContext { get }
    
    // Conversation Operations
    func createConversation(language: String, userLevel: String) async throws -> Conversation
    func endConversation(_ conversation: Conversation) async throws
    func fetchRecentConversations(limit: Int) async throws -> [Conversation]
    func fetchConversations(for language: String, limit: Int?) async throws -> [Conversation]
    func deleteConversation(_ conversation: Conversation) async throws
    
    // Message Operations
    func addMessage(to conversation: Conversation, text: String, isUser: Bool, translation: String?) async throws -> Message
    func fetchMessages(for conversation: Conversation) async throws -> [Message]
    func updateMessageTranslation(_ message: Message, translation: String) async throws
    
    // User Progress Operations
    func fetchOrCreateUserProgress(for language: String) async throws -> UserProgress
    func fetchAllUserProgress() async throws -> [UserProgress]
    func updateUserProgress(for language: String) async throws
    func resetUserProgress(for language: String) async throws
    
    // Vocabulary Operations
    func addVocabularyItem(to conversation: Conversation, word: String, translation: String?, definition: String?) async throws -> VocabularyItem
    func fetchVocabularyForReview(language: String) async throws -> [VocabularyItem]
    func fetchVocabulary(for conversation: Conversation) async throws -> [VocabularyItem]
    func markVocabularyAsReviewed(_ item: VocabularyItem) async throws
    func scheduleNextReview(for item: VocabularyItem) async throws
    
    // Statistics Operations
    func fetchTotalPracticeTime(for language: String?) async throws -> Int
    func fetchMessageCount(for language: String?) async throws -> Int
    func fetchVocabularyCount(for language: String?) async throws -> Int
    func fetchCurrentStreak(for language: String) async throws -> Int
}

// MARK: - PersistenceService Errors

enum PersistenceError: LocalizedError {
    case saveFailed(Error)
    case fetchFailed(Error)
    case entityNotFound(String)
    case invalidData(String)
    case migrationFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            return "Failed to save data: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch data: \(error.localizedDescription)"
        case .entityNotFound(let entity):
            return "Entity not found: \(entity)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .migrationFailed(let error):
            return "Migration failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - PersistenceService Implementation

@MainActor
final class PersistenceService: PersistenceServiceProtocol {
    
    // MARK: - Singleton
    
    static let shared = PersistenceService()
    
    // MARK: - Properties
    
    private let persistenceController: PersistenceController
    var viewContext: NSManagedObjectContext {
        persistenceController.viewContext
    }
    
    // MARK: - Initialization
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }
    
    // MARK: - Context Management
    
    func save() async throws {
        persistenceController.save()
    }
    
    // MARK: - Conversation Operations
    
    func createConversation(language: String, userLevel: String) async throws -> Conversation {
        return await withCheckedContinuation { continuation in
            let conversation = persistenceController.createConversation(
                language: language,
                userLevel: userLevel
            )
            continuation.resume(returning: conversation)
        }
    }
    
    func endConversation(_ conversation: Conversation) async throws {
        persistenceController.endConversation(conversation)
        try await save()
    }
    
    func fetchRecentConversations(limit: Int = 10) async throws -> [Conversation] {
        do {
            return try await withCheckedThrowingContinuation { continuation in
                let conversations = persistenceController.fetchRecentConversations(limit: limit)
                continuation.resume(returning: conversations)
            }
        } catch {
            throw PersistenceError.fetchFailed(error)
        }
    }
    
    func fetchConversations(for language: String, limit: Int? = nil) async throws -> [Conversation] {
        let request: NSFetchRequest<Conversation> = Conversation.fetchRequest()
        request.predicate = NSPredicate(format: "language == %@", language)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Conversation.startTime, ascending: false)]
        
        if let limit = limit {
            request.fetchLimit = limit
        }
        
        do {
            return try viewContext.fetch(request)
        } catch {
            throw PersistenceError.fetchFailed(error)
        }
    }
    
    func deleteConversation(_ conversation: Conversation) async throws {
        viewContext.delete(conversation)
        try await save()
    }
    
    // MARK: - Message Operations
    
    func addMessage(to conversation: Conversation, text: String, isUser: Bool, translation: String? = nil) async throws -> Message {
        return await withCheckedContinuation { continuation in
            let message = persistenceController.addMessage(
                to: conversation,
                text: text,
                isUser: isUser,
                translation: translation
            )
            continuation.resume(returning: message)
        }
    }
    
    func fetchMessages(for conversation: Conversation) async throws -> [Message] {
        guard let messages = conversation.messages as? Set<Message> else {
            return []
        }
        return messages.sorted { 
            guard let timestamp1 = $0.timestamp, let timestamp2 = $1.timestamp else {
                return $0.timestamp != nil
            }
            return timestamp1 < timestamp2
        }
    }
    
    func updateMessageTranslation(_ message: Message, translation: String) async throws {
        message.translation = translation
        try await save()
    }
    
    // MARK: - User Progress Operations
    
    func fetchOrCreateUserProgress(for language: String) async throws -> UserProgress {
        return persistenceController.fetchOrCreateUserProgress(for: language)
    }
    
    func fetchAllUserProgress() async throws -> [UserProgress] {
        let request: NSFetchRequest<UserProgress> = UserProgress.fetchRequest()
        
        do {
            return try viewContext.fetch(request)
        } catch {
            throw PersistenceError.fetchFailed(error)
        }
    }
    
    func updateUserProgress(for language: String) async throws {
        // This is handled internally by endConversation in PersistenceController
        // But we can expose it for manual updates if needed
        let progress = try await fetchOrCreateUserProgress(for: language)
        progress.updateStreak()
        try await save()
    }
    
    func resetUserProgress(for language: String) async throws {
        let progress = try await fetchOrCreateUserProgress(for: language)
        progress.totalSessions = 0
        progress.totalMinutesPracticed = 0
        progress.currentStreak = 0
        progress.longestStreak = 0
        progress.lastSessionDate = nil
        try await save()
    }
    
    // MARK: - Vocabulary Operations
    
    func addVocabularyItem(to conversation: Conversation, word: String, translation: String? = nil, definition: String? = nil) async throws -> VocabularyItem {
        return await withCheckedContinuation { continuation in
            let item = persistenceController.addVocabularyItem(
                to: conversation,
                word: word,
                translation: translation,
                definition: definition
            )
            continuation.resume(returning: item)
        }
    }
    
    func fetchVocabularyForReview(language: String) async throws -> [VocabularyItem] {
        return persistenceController.fetchVocabularyForReview(language: language)
    }
    
    func fetchVocabulary(for conversation: Conversation) async throws -> [VocabularyItem] {
        guard let vocabulary = conversation.vocabularyItems as? Set<VocabularyItem> else {
            return []
        }
        return vocabulary.sorted { 
            guard let word1 = $0.word, let word2 = $1.word else {
                return $0.word != nil
            }
            return word1 < word2
        }
    }
    
    func markVocabularyAsReviewed(_ item: VocabularyItem) async throws {
        item.reviewCount += 1
        item.lastReviewedDate = Date()
        try await save()
    }
    
    func scheduleNextReview(for item: VocabularyItem) async throws {
        item.scheduleNextReview()
        try await save()
    }
    
    // MARK: - Statistics Operations
    
    func fetchTotalPracticeTime(for language: String? = nil) async throws -> Int {
        let request: NSFetchRequest<UserProgress> = UserProgress.fetchRequest()
        
        if let language = language {
            request.predicate = NSPredicate(format: "language == %@", language)
        }
        
        do {
            let progresses = try viewContext.fetch(request)
            return progresses.reduce(0) { $0 + Int($1.totalMinutesPracticed) }
        } catch {
            throw PersistenceError.fetchFailed(error)
        }
    }
    
    func fetchMessageCount(for language: String? = nil) async throws -> Int {
        let request: NSFetchRequest<Message> = Message.fetchRequest()
        
        if let language = language {
            request.predicate = NSPredicate(format: "conversation.language == %@", language)
        }
        
        do {
            return try viewContext.count(for: request)
        } catch {
            throw PersistenceError.fetchFailed(error)
        }
    }
    
    func fetchVocabularyCount(for language: String? = nil) async throws -> Int {
        let request: NSFetchRequest<VocabularyItem> = VocabularyItem.fetchRequest()
        
        if let language = language {
            request.predicate = NSPredicate(format: "conversation.language == %@", language)
        }
        
        do {
            return try viewContext.count(for: request)
        } catch {
            throw PersistenceError.fetchFailed(error)
        }
    }
    
    func fetchCurrentStreak(for language: String) async throws -> Int {
        let progress = try await fetchOrCreateUserProgress(for: language)
        return Int(progress.currentStreak)
    }
}

// MARK: - Convenience Extensions

extension PersistenceService {
    
    // Batch operations for better performance
    func batchAddMessages(to conversation: Conversation, messages: [(text: String, isUser: Bool, translation: String?)]) async throws {
        for message in messages {
            _ = try await addMessage(
                to: conversation,
                text: message.text,
                isUser: message.isUser,
                translation: message.translation
            )
        }
        try await save()
    }
    
    func batchAddVocabulary(to conversation: Conversation, items: [(word: String, translation: String?, definition: String?)]) async throws {
        for item in items {
            _ = try await addVocabularyItem(
                to: conversation,
                word: item.word,
                translation: item.translation,
                definition: item.definition
            )
        }
        try await save()
    }
    
    // Analytics helpers
    func fetchLanguageStatistics() async throws -> [String: (sessions: Int, minutes: Int, streak: Int)] {
        let allProgress = try await fetchAllUserProgress()
        
        var statistics: [String: (sessions: Int, minutes: Int, streak: Int)] = [:]
        
        for progress in allProgress {
            guard let language = progress.language else { continue }
            statistics[language] = (
                sessions: Int(progress.totalSessions),
                minutes: Int(progress.totalMinutesPracticed),
                streak: Int(progress.currentStreak)
            )
        }
        
        return statistics
    }
}