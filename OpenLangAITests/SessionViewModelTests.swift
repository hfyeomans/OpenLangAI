import XCTest
import Combine
@testable import OpenLangAI
@testable import OpenAIClientKit
@testable import PersistenceKit

// MARK: - Mock Objects

class MockPersistenceController {
    var createConversationCalled = false
    var endConversationCalled = false
    var addMessageCalled = false
    var lastCreatedConversation: Conversation?
    var messages: [(conversation: Conversation, text: String, isUser: Bool)] = []
    
    func createConversation(language: String, userLevel: String) -> Conversation? {
        createConversationCalled = true
        // Create a mock conversation
        let conversation = Conversation(context: PersistenceController.shared.container.viewContext)
        conversation.id = UUID()
        conversation.language = language
        conversation.userLevel = userLevel
        conversation.startTime = Date()
        lastCreatedConversation = conversation
        return conversation
    }
    
    func endConversation(_ conversation: Conversation) {
        endConversationCalled = true
        conversation.endTime = Date()
    }
    
    func addMessage(to conversation: Conversation, text: String, isUser: Bool) -> Message? {
        addMessageCalled = true
        messages.append((conversation: conversation, text: text, isUser: isUser))
        // Create a mock message
        let message = Message(context: PersistenceController.shared.container.viewContext)
        message.id = UUID()
        message.text = text
        message.isUser = isUser
        message.timestamp = Date()
        message.conversation = conversation
        return message
    }
    
    func reset() {
        createConversationCalled = false
        endConversationCalled = false
        addMessageCalled = false
        lastCreatedConversation = nil
        messages.removeAll()
    }
}

class MockLLMClientSession {
    static let shared = MockLLMClientSession()
    
    var sendMessageCalled = false
    var lastMessage: String?
    var lastProvider: LLMProvider?
    var lastLanguage: String?
    var shouldThrowError = false
    var mockResponse = "Mock AI response"
    var responseDelay: TimeInterval = 0
    
    func sendMessage(_ message: String, provider: LLMProvider, language: String) async throws -> String {
        sendMessageCalled = true
        lastMessage = message
        lastProvider = provider
        lastLanguage = language
        
        if responseDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
        }
        
        if shouldThrowError {
            throw NSError(domain: "MockLLMClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock LLM error"])
        }
        
        return mockResponse
    }
    
    func reset() {
        sendMessageCalled = false
        lastMessage = nil
        lastProvider = nil
        lastLanguage = nil
        shouldThrowError = false
        mockResponse = "Mock AI response"
        responseDelay = 0
    }
}

// MARK: - TestableSessionViewModel

@MainActor
class TestableSessionViewModel: ObservableObject {
    // MARK: - Published Properties (same as original)
    @Published var isRecording = false
    @Published var transcript: [TranscriptEntry] = []
    @Published var currentUserText = ""
    @Published var showTranslation = false
    @Published var isProcessing = false
    @Published var showingRecap = false
    @Published var currentConversation: Conversation?
    @Published var errorMessage: String?
    
    // MARK: - User Preferences
    let selectedLanguage: Language
    let userLevel: String
    
    // MARK: - Services
    private let audioService: AudioServiceProtocol
    let mockPersistenceController: MockPersistenceController
    let mockLLMClient: MockLLMClientSession
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(
        selectedLanguage: Language = .spanish,
        userLevel: String = "beginner",
        audioService: AudioServiceProtocol? = nil,
        mockPersistenceController: MockPersistenceController = MockPersistenceController(),
        mockLLMClient: MockLLMClientSession = MockLLMClientSession.shared
    ) {
        self.selectedLanguage = selectedLanguage
        self.userLevel = userLevel
        self.audioService = audioService ?? MockAudioService()
        self.mockPersistenceController = mockPersistenceController
        self.mockLLMClient = mockLLMClient
        
        setupAudioServiceBindings()
    }
    
    // MARK: - Public Methods (mimicking original)
    
    func onAppear() {
        Task {
            _ = await audioService.requestPermissions()
        }
        startNewConversation()
    }
    
    func onDisappear() {
        Task {
            await audioService.stopRecording()
        }
        if let conversation = currentConversation {
            mockPersistenceController.endConversation(conversation)
        }
    }
    
    func toggleRecording() {
        Task {
            if isRecording {
                await audioService.stopRecording()
            } else {
                await startRecording()
            }
        }
    }
    
    func endSession() {
        Task {
            await audioService.stopRecording()
        }
        if let conversation = currentConversation {
            mockPersistenceController.endConversation(conversation)
            showingRecap = true
        }
    }
    
    // MARK: - Audio Service Setup
    
    private func setupAudioServiceBindings() {
        // Subscribe to isRecording state
        audioService.isRecordingPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                self?.isRecording = isRecording
            }
            .store(in: &cancellables)
        
        // Subscribe to current transcription updates
        audioService.currentTranscriptionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transcription in
                self?.currentUserText = transcription
            }
            .store(in: &cancellables)
        
        // Subscribe to final transcription
        audioService.finalTranscriptionPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] finalTranscription in
                self?.processUserInput(finalTranscription)
            }
            .store(in: &cancellables)
        
        // Subscribe to errors
        audioService.errorPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.errorMessage = error.localizedDescription
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Recording Management
    
    private func startRecording() async {
        do {
            currentUserText = ""
            errorMessage = nil
            try await audioService.startRecording(language: selectedLanguage.rawValue)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Message Processing
    
    func processUserInput(_ text: String) {
        guard !text.isEmpty else { return }
        
        isProcessing = true
        errorMessage = nil
        
        // Add user message to transcript
        let userEntry = TranscriptEntry(
            text: text,
            translation: nil,
            isUser: true,
            timestamp: Date()
        )
        transcript.append(userEntry)
        currentUserText = ""
        
        // Save to Core Data
        if let conversation = currentConversation {
            _ = mockPersistenceController.addMessage(
                to: conversation,
                text: text,
                isUser: true
            )
        }
        
        // Get AI response
        Task {
            await getAIResponse(for: text)
        }
    }
    
    private func getAIResponse(for userText: String) async {
        do {
            let response = try await mockLLMClient.sendMessage(
                userText,
                provider: .chatGPT,
                language: selectedLanguage.rawValue
            )
            
            await MainActor.run {
                let aiEntry = TranscriptEntry(
                    text: response,
                    translation: nil,
                    isUser: false,
                    timestamp: Date()
                )
                transcript.append(aiEntry)
                isProcessing = false
                
                // Save AI response to Core Data
                if let conversation = currentConversation {
                    _ = mockPersistenceController.addMessage(
                        to: conversation,
                        text: response,
                        isUser: false
                    )
                }
                
                // Speak the response
                speakText(response)
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to get AI response: \(error.localizedDescription)"
                isProcessing = false
            }
        }
    }
    
    // MARK: - Text-to-Speech
    
    private func speakText(_ text: String) {
        Task {
            await audioService.speakText(text, language: selectedLanguage.rawValue)
        }
    }
    
    // MARK: - Conversation Management
    
    private func startNewConversation() {
        currentConversation = mockPersistenceController.createConversation(
            language: selectedLanguage.rawValue,
            userLevel: userLevel
        )
    }
}

// MARK: - SessionViewModel Tests

@MainActor
final class SessionViewModelTests: XCTestCase {
    
    var viewModel: TestableSessionViewModel!
    var mockAudioService: MockAudioService!
    var mockPersistenceController: MockPersistenceController!
    var mockLLMClient: MockLLMClientSession!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        
        // Setup mocks
        mockAudioService = MockAudioService()
        mockPersistenceController = MockPersistenceController()
        mockLLMClient = MockLLMClientSession.shared
        
        // Reset all mocks
        mockAudioService.reset()
        mockPersistenceController.reset()
        mockLLMClient.reset()
        
        // Create view model
        viewModel = TestableSessionViewModel(
            selectedLanguage: .spanish,
            userLevel: "beginner",
            audioService: mockAudioService,
            mockPersistenceController: mockPersistenceController,
            mockLLMClient: mockLLMClient
        )
        
        cancellables = []
    }
    
    override func tearDown() {
        viewModel = nil
        mockAudioService = nil
        mockPersistenceController = nil
        mockLLMClient = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertFalse(viewModel.isRecording)
        XCTAssertTrue(viewModel.transcript.isEmpty)
        XCTAssertEqual(viewModel.currentUserText, "")
        XCTAssertFalse(viewModel.showTranslation)
        XCTAssertFalse(viewModel.isProcessing)
        XCTAssertFalse(viewModel.showingRecap)
        XCTAssertNil(viewModel.currentConversation)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.selectedLanguage, .spanish)
        XCTAssertEqual(viewModel.userLevel, "beginner")
    }
    
    func testInitializationWithCustomValues() {
        let customViewModel = TestableSessionViewModel(
            selectedLanguage: .french,
            userLevel: "intermediate"
        )
        
        XCTAssertEqual(customViewModel.selectedLanguage, .french)
        XCTAssertEqual(customViewModel.userLevel, "intermediate")
    }
    
    // MARK: - Lifecycle Tests
    
    func testOnAppear() async {
        mockAudioService.simulatedPermissionGranted = true
        
        viewModel.onAppear()
        
        // Wait for async permission request
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        // Verify conversation creation
        XCTAssertTrue(mockPersistenceController.createConversationCalled)
        XCTAssertNotNil(viewModel.currentConversation)
        XCTAssertEqual(mockPersistenceController.lastCreatedConversation?.language, "Spanish")
        XCTAssertEqual(mockPersistenceController.lastCreatedConversation?.userLevel, "beginner")
    }
    
    func testOnAppearWithDeniedPermissions() async {
        mockAudioService.simulatedPermissionGranted = false
        mockAudioService.shouldFailPermissions = true
        
        viewModel.onAppear()
        
        // Wait for async permission request
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        // Conversation should still be created even if permissions are denied
        XCTAssertTrue(mockPersistenceController.createConversationCalled)
    }
    
    func testOnDisappear() async {
        // Setup: Create a conversation first
        viewModel.onAppear()
        
        // Start recording
        mockAudioService.simulatedPermissionGranted = true
        viewModel.toggleRecording()
        
        // Wait for recording to start
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        // Call onDisappear
        viewModel.onDisappear()
        
        // Wait for async stop
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        // Verify recording stopped
        XCTAssertEqual(mockAudioService.stopRecordingCallCount, 1)
        
        // Verify conversation ended
        XCTAssertTrue(mockPersistenceController.endConversationCalled)
    }
    
    // MARK: - Recording Tests
    
    func testToggleRecordingStartStop() async {
        mockAudioService.simulatedPermissionGranted = true
        viewModel.onAppear()
        
        // Start recording
        viewModel.toggleRecording()
        
        // Wait for async start
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        XCTAssertTrue(viewModel.isRecording)
        XCTAssertEqual(mockAudioService.startRecordingCallCount, 1)
        XCTAssertEqual(mockAudioService.lastRecordingLanguage, "Spanish")
        XCTAssertEqual(viewModel.currentUserText, "")
        XCTAssertNil(viewModel.errorMessage)
        
        // Stop recording
        viewModel.toggleRecording()
        
        // Wait for async stop
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        XCTAssertFalse(viewModel.isRecording)
        XCTAssertEqual(mockAudioService.stopRecordingCallCount, 1)
    }
    
    func testStartRecordingWithAudioServiceError() async {
        viewModel.onAppear()
        mockAudioService.shouldFailStartRecording = true
        
        viewModel.toggleRecording()
        
        // Wait for async start attempt
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        XCTAssertFalse(viewModel.isRecording)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage?.contains("Audio engine error") ?? false)
    }
    
    // MARK: - Message Processing Tests
    
    func testProcessUserInput() async {
        viewModel.onAppear() // Setup conversation
        
        let userText = "Hola, ¿cómo estás?"
        viewModel.processUserInput(userText)
        
        // Verify user message added to transcript
        XCTAssertEqual(viewModel.transcript.count, 1)
        XCTAssertEqual(viewModel.transcript[0].text, userText)
        XCTAssertTrue(viewModel.transcript[0].isUser)
        XCTAssertNil(viewModel.transcript[0].translation)
        
        // Verify processing state
        XCTAssertTrue(viewModel.isProcessing)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.currentUserText, "")
        
        // Verify message saved to Core Data
        XCTAssertTrue(mockPersistenceController.addMessageCalled)
        XCTAssertEqual(mockPersistenceController.messages.count, 1)
        XCTAssertEqual(mockPersistenceController.messages[0].text, userText)
        XCTAssertTrue(mockPersistenceController.messages[0].isUser)
        
        // Wait for AI response
        let expectation = XCTestExpectation(description: "AI response received")
        
        viewModel.$isProcessing
            .dropFirst()
            .sink { isProcessing in
                if !isProcessing {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        await fulfillment(of: [expectation], timeout: 2.0)
        
        // Verify AI response
        XCTAssertEqual(viewModel.transcript.count, 2)
        XCTAssertEqual(viewModel.transcript[1].text, "Mock AI response")
        XCTAssertFalse(viewModel.transcript[1].isUser)
        XCTAssertFalse(viewModel.isProcessing)
        
        // Verify LLM client called
        XCTAssertTrue(mockLLMClient.sendMessageCalled)
        XCTAssertEqual(mockLLMClient.lastMessage, userText)
        XCTAssertEqual(mockLLMClient.lastProvider, .chatGPT)
        XCTAssertEqual(mockLLMClient.lastLanguage, "Spanish")
        
        // Verify speech synthesis called
        XCTAssertEqual(mockAudioService.speakTextCallCount, 1)
        XCTAssertEqual(mockAudioService.lastSpokenText, "Mock AI response")
        XCTAssertEqual(mockAudioService.lastSpokenLanguage, "Spanish")
    }
    
    func testProcessEmptyUserInput() {
        viewModel.processUserInput("")
        
        XCTAssertTrue(viewModel.transcript.isEmpty)
        XCTAssertFalse(viewModel.isProcessing)
        XCTAssertFalse(mockPersistenceController.addMessageCalled)
    }
    
    func testProcessUserInputWithLLMError() async {
        viewModel.onAppear()
        mockLLMClient.shouldThrowError = true
        
        let userText = "Test message"
        viewModel.processUserInput(userText)
        
        // Wait for error
        let expectation = XCTestExpectation(description: "Error received")
        
        viewModel.$errorMessage
            .compactMap { $0 }
            .sink { _ in
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        await fulfillment(of: [expectation], timeout: 2.0)
        
        // Verify error handling
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage?.contains("Failed to get AI response") ?? false)
        XCTAssertFalse(viewModel.isProcessing)
        XCTAssertEqual(viewModel.transcript.count, 1) // Only user message
        XCTAssertEqual(mockAudioService.speakTextCallCount, 0)
    }
    
    // MARK: - Session Management Tests
    
    func testEndSession() async {
        viewModel.onAppear()
        
        // Start recording
        viewModel.toggleRecording()
        
        // Wait for recording to start
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        // End session
        viewModel.endSession()
        
        // Wait for async stop
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        // Verify recording stopped
        XCTAssertEqual(mockAudioService.stopRecordingCallCount, 1)
        
        // Verify conversation ended
        XCTAssertTrue(mockPersistenceController.endConversationCalled)
        XCTAssertTrue(viewModel.showingRecap)
    }
    
    func testEndSessionWithoutConversation() async {
        // Don't call onAppear to skip conversation creation
        viewModel.endSession()
        
        // Wait for async operations
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        XCTAssertFalse(mockPersistenceController.endConversationCalled)
        XCTAssertFalse(viewModel.showingRecap)
    }
    
    // MARK: - Audio Service Integration Tests
    
    func testTranscriptionUpdates() async {
        mockAudioService.simulatedPermissionGranted = true
        
        // Simulate partial transcriptions
        mockAudioService.simulateTranscription("Hello")
        
        // Wait for update
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 second
        
        XCTAssertEqual(viewModel.currentUserText, "Hello")
        
        mockAudioService.simulateTranscription("Hello world")
        
        // Wait for update
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 second
        
        XCTAssertEqual(viewModel.currentUserText, "Hello world")
    }
    
    func testFinalTranscriptionTriggersProcessing() async {
        viewModel.onAppear()
        
        let finalText = "Final transcription text"
        mockAudioService.simulateFinalTranscription(finalText)
        
        // Wait for processing
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        
        // Verify transcript updated
        XCTAssertTrue(viewModel.transcript.count >= 1)
        XCTAssertEqual(viewModel.transcript[0].text, finalText)
        XCTAssertTrue(viewModel.transcript[0].isUser)
    }
    
    func testAudioServiceErrorHandling() async {
        let testError = AudioServiceError.permissionDenied
        mockAudioService.simulateError(testError)
        
        // Wait for error propagation
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 second
        
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.errorMessage, testError.localizedDescription)
    }
    
    // MARK: - Language Support Tests
    
    func testLanguageSupport() async {
        let testCases: [(Language, String)] = [
            (.spanish, "Spanish"),
            (.french, "French"),
            (.japanese, "Japanese"),
            (.italian, "Italian"),
            (.portuguese, "Portuguese")
        ]
        
        for (language, expectedLanguageName) in testCases {
            let vm = TestableSessionViewModel(
                selectedLanguage: language,
                audioService: mockAudioService
            )
            vm.onAppear()
            
            // Start recording
            vm.toggleRecording()
            
            // Wait for async start
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            
            // Verify correct language passed to audio service
            XCTAssertEqual(mockAudioService.lastRecordingLanguage, expectedLanguageName)
            
            // Reset for next test
            mockAudioService.reset()
        }
    }
    
    // MARK: - Concurrent Operations Tests
    
    func testMultipleProcessUserInputCalls() async {
        viewModel.onAppear()
        
        // Process multiple messages quickly
        viewModel.processUserInput("Message 1")
        viewModel.processUserInput("Message 2")
        viewModel.processUserInput("Message 3")
        
        // Wait for all processing to complete
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Should have 6 transcript entries (3 user + 3 AI)
        XCTAssertEqual(viewModel.transcript.count, 6)
        XCTAssertFalse(viewModel.isProcessing)
    }
    
    // MARK: - Memory Management Tests
    
    func testNoRetainCycles() {
        weak var weakViewModel = viewModel
        weak var weakAudioService = mockAudioService
        
        // Subscribe to publishers
        viewModel.$isRecording.sink { _ in }.store(in: &cancellables)
        viewModel.$transcript.sink { _ in }.store(in: &cancellables)
        viewModel.$isProcessing.sink { _ in }.store(in: &cancellables)
        
        // Process a message to create async tasks
        viewModel.processUserInput("Test message")
        
        // Clear references
        viewModel = nil
        mockAudioService = nil
        cancellables.removeAll()
        
        // Verify deallocation
        XCTAssertNil(weakViewModel)
        XCTAssertNil(weakAudioService)
    }
    
    // MARK: - State Consistency Tests
    
    func testStateConsistencyDuringProcessing() async {
        viewModel.onAppear()
        
        // Set a delay for the mock response
        mockLLMClient.responseDelay = 0.5
        
        viewModel.processUserInput("Test message")
        
        // Verify state during processing
        XCTAssertTrue(viewModel.isProcessing)
        XCTAssertEqual(viewModel.transcript.count, 1) // Only user message
        
        // Wait for processing to complete
        try? await Task.sleep(nanoseconds: 700_000_000) // 0.7 seconds
        
        // Verify final state
        XCTAssertFalse(viewModel.isProcessing)
        XCTAssertEqual(viewModel.transcript.count, 2) // User + AI messages
    }
}

// MARK: - Test Helpers

extension SessionViewModelTests {
    func clearUserDefaults() {
        UserDefaults.standard.removeObject(forKey: "selectedLanguage")
        UserDefaults.standard.removeObject(forKey: "userLevel")
    }
}