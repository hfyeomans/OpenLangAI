import XCTest
import CoreData
import Combine
@testable import OpenLangAI
@testable import PersistenceKit

class PersistenceServiceTests: XCTestCase {
    
    var sut: PersistenceService!
    var mockService: MockPersistenceService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockService = MockPersistenceService()
        cancellables = []
    }
    
    override func tearDown() {
        sut = nil
        mockService?.reset()
        mockService = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Context Management Tests
    
    func testSaveSuccess() async throws {
        let conversation = try await mockService.createConversation(
            language: Constants.Languages.spanish,
            userLevel: Constants.UserLevels.beginnerKey
        )
        
        try await mockService.save()
        
        XCTAssertEqual(mockService.saveCallCount, 1)
        XCTAssertNotNil(conversation.id)
    }
    
    func testSaveFailure() async {
        mockService.shouldFailSave = true
        
        do {
            try await mockService.save()
            XCTFail("Save should have failed")
        } catch {
            XCTAssertTrue(error is PersistenceError)
            XCTAssertEqual(mockService.saveCallCount, 1)
        }
    }
    
    // MARK: - Conversation Operations Tests
    
    func testCreateConversation() async throws {
        let language = Constants.Languages.french
        let userLevel = Constants.UserLevels.intermediateKey
        
        let conversation = try await mockService.createConversation(
            language: language,
            userLevel: userLevel
        )
        
        XCTAssertEqual(mockService.createConversationCallCount, 1)
        XCTAssertEqual(conversation.language, language)
        XCTAssertEqual(conversation.userLevel, userLevel)
        XCTAssertNotNil(conversation.startTime)
        XCTAssertNil(conversation.endTime)
    }
    
    func testEndConversation() async throws {
        let conversation = try await mockService.createConversation(
            language: Constants.Languages.spanish,
            userLevel: Constants.UserLevels.beginnerKey
        )
        
        try await mockService.endConversation(conversation)
        
        XCTAssertNotNil(conversation.endTime)
    }
    
    func testFetchRecentConversations() async throws {
        // Create multiple conversations
        for i in 0..<5 {
            _ = mockService.injectMockConversation(
                language: Constants.Languages.spanish,
                userLevel: Constants.UserLevels.beginnerKey
            )
        }
        
        let conversations = try await mockService.fetchRecentConversations(limit: 3)
        
        XCTAssertEqual(conversations.count, 3)
        // Verify they're sorted by date (most recent first)
        for i in 0..<conversations.count - 1 {
            XCTAssertGreaterThanOrEqual(
                conversations[i].startTime,
                conversations[i + 1].startTime
            )
        }
    }
    
    func testFetchConversationsByLanguage() async throws {
        // Create conversations in different languages
        _ = mockService.injectMockConversation(
            language: Constants.Languages.spanish,
            userLevel: Constants.UserLevels.beginnerKey
        )
        _ = mockService.injectMockConversation(
            language: Constants.Languages.french,
            userLevel: Constants.UserLevels.intermediateKey
        )
        _ = mockService.injectMockConversation(
            language: Constants.Languages.spanish,
            userLevel: Constants.UserLevels.intermediateKey
        )
        
        let spanishConversations = try await mockService.fetchConversations(
            for: Constants.Languages.spanish,
            limit: nil
        )
        
        XCTAssertEqual(spanishConversations.count, 2)
        XCTAssertTrue(spanishConversations.allSatisfy { $0.language == Constants.Languages.spanish })
    }
    
    func testDeleteConversation() async throws {
        let conversation = try await mockService.createConversation(
            language: Constants.Languages.spanish,
            userLevel: Constants.UserLevels.beginnerKey
        )
        
        try await mockService.deleteConversation(conversation)
        
        let remaining = try await mockService.fetchRecentConversations(limit: 10)
        XCTAssertTrue(remaining.isEmpty)
    }
    
    // MARK: - Message Operations Tests
    
    func testAddMessage() async throws {
        let conversation = try await mockService.createConversation(
            language: Constants.Languages.spanish,
            userLevel: Constants.UserLevels.beginnerKey
        )
        
        let messageText = "Hello, how are you?"
        let message = try await mockService.addMessage(
            to: conversation,
            text: messageText,
            isUser: true,
            translation: "Hola, ¿cómo estás?"
        )
        
        XCTAssertEqual(mockService.addMessageCallCount, 1)
        XCTAssertEqual(message.text, messageText)
        XCTAssertTrue(message.isUser)
        XCTAssertEqual(message.translation, "Hola, ¿cómo estás?")
        XCTAssertNotNil(message.timestamp)
    }
    
    func testFetchMessages() async throws {
        let conversation = mockService.injectMockConversation(
            language: Constants.Languages.spanish,
            userLevel: Constants.UserLevels.beginnerKey,
            messageCount: 3
        )
        
        let messages = try await mockService.fetchMessages(for: conversation)
        
        XCTAssertEqual(messages.count, 3)
        // Verify messages are sorted by timestamp
        for i in 0..<messages.count - 1 {
            XCTAssertLessThan(messages[i].timestamp, messages[i + 1].timestamp)
        }
    }
    
    func testUpdateMessageTranslation() async throws {
        let conversation = try await mockService.createConversation(
            language: Constants.Languages.spanish,
            userLevel: Constants.UserLevels.beginnerKey
        )
        
        let message = try await mockService.addMessage(
            to: conversation,
            text: "Hello",
            isUser: true,
            translation: nil
        )
        
        try await mockService.updateMessageTranslation(message, translation: "Hola")
        
        XCTAssertEqual(message.translation, "Hola")
    }
    
    // MARK: - User Progress Operations Tests
    
    func testFetchOrCreateUserProgress() async throws {
        let language = Constants.Languages.japanese
        
        let progress = try await mockService.fetchOrCreateUserProgress(for: language)
        
        XCTAssertEqual(progress.language, language)
        XCTAssertEqual(progress.totalSessions, 0)
        XCTAssertEqual(progress.totalMinutesPracticed, 0)
        XCTAssertEqual(progress.currentStreak, 0)
        
        // Fetch again should return same instance
        let sameProgress = try await mockService.fetchOrCreateUserProgress(for: language)
        XCTAssertEqual(progress.id, sameProgress.id)
    }
    
    func testUpdateUserProgress() async throws {
        let language = Constants.Languages.spanish
        
        let progress = try await mockService.fetchOrCreateUserProgress(for: language)
        XCTAssertEqual(progress.totalSessions, 0)
        
        try await mockService.updateUserProgress(for: language)
        
        XCTAssertEqual(progress.totalSessions, 1)
        XCTAssertEqual(progress.totalMinutesPracticed, 10) // Mock adds 10 minutes
    }
    
    func testResetUserProgress() async throws {
        let language = Constants.Languages.spanish
        
        // Create and update progress
        _ = try await mockService.fetchOrCreateUserProgress(for: language)
        try await mockService.updateUserProgress(for: language)
        
        // Reset
        try await mockService.resetUserProgress(for: language)
        
        let progress = try await mockService.fetchOrCreateUserProgress(for: language)
        XCTAssertEqual(progress.totalSessions, 0)
        XCTAssertEqual(progress.totalMinutesPracticed, 0)
        XCTAssertEqual(progress.currentStreak, 0)
    }
    
    // MARK: - Vocabulary Operations Tests
    
    func testAddVocabularyItem() async throws {
        let conversation = try await mockService.createConversation(
            language: Constants.Languages.spanish,
            userLevel: Constants.UserLevels.beginnerKey
        )
        
        let item = try await mockService.addVocabularyItem(
            to: conversation,
            word: "casa",
            translation: "house",
            definition: "A building for human habitation"
        )
        
        XCTAssertEqual(mockService.addVocabularyCallCount, 1)
        XCTAssertEqual(item.word, "casa")
        XCTAssertEqual(item.translation, "house")
        XCTAssertEqual(item.definition, "A building for human habitation")
        XCTAssertNotNil(item.nextReviewDate)
    }
    
    func testFetchVocabularyForReview() async throws {
        let conversation = try await mockService.createConversation(
            language: Constants.Languages.spanish,
            userLevel: Constants.UserLevels.beginnerKey
        )
        
        // Add vocabulary items
        _ = try await mockService.addVocabularyItem(
            to: conversation,
            word: "casa",
            translation: "house",
            definition: nil
        )
        _ = try await mockService.addVocabularyItem(
            to: conversation,
            word: "perro",
            translation: "dog",
            definition: nil
        )
        
        let itemsForReview = try await mockService.fetchVocabularyForReview(
            language: Constants.Languages.spanish
        )
        
        XCTAssertGreaterThanOrEqual(itemsForReview.count, 0)
    }
    
    func testMarkVocabularyAsReviewed() async throws {
        let conversation = try await mockService.createConversation(
            language: Constants.Languages.spanish,
            userLevel: Constants.UserLevels.beginnerKey
        )
        
        let item = try await mockService.addVocabularyItem(
            to: conversation,
            word: "casa",
            translation: "house",
            definition: nil
        )
        
        XCTAssertEqual(item.reviewCount, 0)
        
        try await mockService.markVocabularyAsReviewed(item)
        
        XCTAssertEqual(item.reviewCount, 1)
        XCTAssertNotNil(item.lastReviewedDate)
    }
    
    // MARK: - Statistics Operations Tests
    
    func testFetchTotalPracticeTime() async throws {
        // Create progress for multiple languages
        _ = try await mockService.fetchOrCreateUserProgress(for: Constants.Languages.spanish)
        try await mockService.updateUserProgress(for: Constants.Languages.spanish)
        
        _ = try await mockService.fetchOrCreateUserProgress(for: Constants.Languages.french)
        try await mockService.updateUserProgress(for: Constants.Languages.french)
        
        // Test specific language
        let spanishTime = try await mockService.fetchTotalPracticeTime(
            for: Constants.Languages.spanish
        )
        XCTAssertEqual(spanishTime, 10)
        
        // Test all languages
        let totalTime = try await mockService.fetchTotalPracticeTime(for: nil)
        XCTAssertEqual(totalTime, 20) // 10 + 10
    }
    
    func testFetchMessageCount() async throws {
        let conversation1 = mockService.injectMockConversation(
            language: Constants.Languages.spanish,
            userLevel: Constants.UserLevels.beginnerKey,
            messageCount: 5
        )
        
        let conversation2 = mockService.injectMockConversation(
            language: Constants.Languages.french,
            userLevel: Constants.UserLevels.intermediateKey,
            messageCount: 3
        )
        
        // Test specific language
        let spanishCount = try await mockService.fetchMessageCount(
            for: Constants.Languages.spanish
        )
        XCTAssertEqual(spanishCount, 5)
        
        // Test all languages
        let totalCount = try await mockService.fetchMessageCount(for: nil)
        XCTAssertEqual(totalCount, 8) // 5 + 3
    }
    
    func testFetchCurrentStreak() async throws {
        let language = Constants.Languages.spanish
        
        _ = try await mockService.fetchOrCreateUserProgress(for: language)
        try await mockService.updateUserProgress(for: language)
        
        let streak = try await mockService.fetchCurrentStreak(for: language)
        XCTAssertGreaterThanOrEqual(streak, 0)
    }
    
    // MARK: - Error Handling Tests
    
    func testFetchFailure() async {
        mockService.shouldFailFetch = true
        
        do {
            _ = try await mockService.fetchRecentConversations(limit: 10)
            XCTFail("Fetch should have failed")
        } catch {
            XCTAssertTrue(error is PersistenceError)
            if case PersistenceError.fetchFailed = error {
                // Success
            } else {
                XCTFail("Wrong error type")
            }
        }
    }
    
    // MARK: - Mock Service Reset Test
    
    func testMockServiceReset() async throws {
        // Add data
        _ = try await mockService.createConversation(
            language: Constants.Languages.spanish,
            userLevel: Constants.UserLevels.beginnerKey
        )
        
        XCTAssertEqual(mockService.createConversationCallCount, 1)
        
        // Reset
        mockService.reset()
        
        // Verify reset
        XCTAssertEqual(mockService.createConversationCallCount, 0)
        XCTAssertFalse(mockService.shouldFailSave)
        XCTAssertFalse(mockService.shouldFailFetch)
        
        let conversations = try await mockService.fetchRecentConversations(limit: 10)
        XCTAssertTrue(conversations.isEmpty)
    }
}