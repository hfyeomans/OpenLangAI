import XCTest
import Combine
@testable import OpenLangAI

class AudioServiceTests: XCTestCase {
    
    var sut: AudioService!
    var mockService: MockAudioService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        sut = AudioService()
        mockService = MockAudioService()
        cancellables = []
    }
    
    override func tearDown() {
        sut = nil
        mockService = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Mock Service Tests
    
    func testMockServiceInitialState() {
        XCTAssertFalse(mockService.isRecording)
        XCTAssertEqual(mockService.startRecordingCallCount, 0)
        XCTAssertEqual(mockService.stopRecordingCallCount, 0)
        XCTAssertEqual(mockService.speakTextCallCount, 0)
    }
    
    func testMockServiceRequestPermissions() async {
        // Test granted permissions
        mockService.simulatedPermissionGranted = true
        let granted = await mockService.requestPermissions()
        XCTAssertTrue(granted)
        
        // Test denied permissions
        mockService.simulatedPermissionGranted = false
        let denied = await mockService.requestPermissions()
        XCTAssertFalse(denied)
        
        // Test failure
        mockService.shouldFailPermissions = true
        let failed = await mockService.requestPermissions()
        XCTAssertFalse(failed)
    }
    
    func testMockServiceStartRecording() async throws {
        // Setup expectations
        let recordingExpectation = expectation(description: "Recording started")
        let transcriptionExpectation = expectation(description: "Transcription received")
        let finalExpectation = expectation(description: "Final transcription received")
        
        mockService.simulatedTranscriptions = ["Hello", "Hello world"]
        mockService.simulatedFinalTranscription = "Hello world!"
        
        var receivedTranscriptions: [String] = []
        var receivedFinal: String?
        
        mockService.currentTranscriptionPublisher
            .sink { transcription in
                receivedTranscriptions.append(transcription)
                if receivedTranscriptions.count == 2 {
                    transcriptionExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        mockService.finalTranscriptionPublisher
            .sink { final in
                receivedFinal = final
                finalExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        mockService.isRecordingPublisher
            .dropFirst()
            .sink { isRecording in
                if isRecording {
                    recordingExpectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Start recording
        try await mockService.startRecording(language: "English")
        
        // Wait for expectations
        await fulfillment(of: [recordingExpectation, transcriptionExpectation, finalExpectation], timeout: 2)
        
        XCTAssertEqual(mockService.startRecordingCallCount, 1)
        XCTAssertEqual(mockService.lastRecordingLanguage, "English")
        XCTAssertEqual(receivedTranscriptions, ["Hello", "Hello world"])
        XCTAssertEqual(receivedFinal, "Hello world!")
        XCTAssertFalse(mockService.isRecording) // Should stop after final
    }
    
    func testMockServiceStartRecordingFailure() async {
        mockService.shouldFailStartRecording = true
        
        do {
            try await mockService.startRecording(language: "English")
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertNotNil(error as? AudioServiceError)
        }
        
        XCTAssertEqual(mockService.startRecordingCallCount, 1)
        XCTAssertFalse(mockService.isRecording)
    }
    
    func testMockServiceStopRecording() async {
        // Start recording first
        mockService._isRecording = true
        
        await mockService.stopRecording()
        
        XCTAssertEqual(mockService.stopRecordingCallCount, 1)
        XCTAssertFalse(mockService.isRecording)
    }
    
    func testMockServiceSpeakText() async {
        let speechExpectation = expectation(description: "Speech completed")
        
        mockService.speechCompletionPublisher
            .sink { _ in
                speechExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        await mockService.speakText("Hello world", language: "English")
        
        await fulfillment(of: [speechExpectation], timeout: 1)
        
        XCTAssertEqual(mockService.speakTextCallCount, 1)
        XCTAssertEqual(mockService.lastSpokenText, "Hello world")
        XCTAssertEqual(mockService.lastSpokenLanguage, "English")
    }
    
    func testMockServiceSimulateError() {
        let errorExpectation = expectation(description: "Error received")
        let testError = NSError(domain: "TestError", code: 123, userInfo: nil)
        
        mockService.errorPublisher
            .sink { error in
                XCTAssertEqual((error as NSError).code, 123)
                errorExpectation.fulfill()
            }
            .store(in: &cancellables)
        
        mockService._isRecording = true
        mockService.simulateError(testError)
        
        wait(for: [errorExpectation], timeout: 1)
        XCTAssertFalse(mockService.isRecording)
    }
    
    func testMockServiceReset() {
        // Setup some state
        mockService.shouldFailPermissions = true
        mockService.startRecordingCallCount = 5
        mockService.lastSpokenText = "Test"
        mockService._isRecording = true
        
        // Reset
        mockService.reset()
        
        // Verify all state is cleared
        XCTAssertFalse(mockService.shouldFailPermissions)
        XCTAssertEqual(mockService.startRecordingCallCount, 0)
        XCTAssertNil(mockService.lastSpokenText)
        XCTAssertFalse(mockService.isRecording)
    }
    
    // MARK: - AudioService Error Tests
    
    func testAudioServiceErrorDescriptions() {
        let permissionError = AudioServiceError.permissionDenied
        XCTAssertEqual(permissionError.errorDescription, "Microphone or speech recognition permission denied")
        
        let unavailableError = AudioServiceError.speechRecognitionNotAvailable
        XCTAssertEqual(unavailableError.errorDescription, "Speech recognition is not available on this device")
        
        let testError = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let engineError = AudioServiceError.audioEngineError(testError)
        XCTAssertTrue(engineError.errorDescription?.contains("Test error") ?? false)
        
        let recognitionError = AudioServiceError.recognitionError(testError)
        XCTAssertTrue(recognitionError.errorDescription?.contains("Test error") ?? false)
        
        let sessionError = AudioServiceError.audioSessionError(testError)
        XCTAssertTrue(sessionError.errorDescription?.contains("Test error") ?? false)
    }
    
    // MARK: - AudioSessionMode Tests
    
    func testAudioSessionModes() {
        // Just verify the enum cases exist
        let recording = AudioSessionMode.recording
        let playback = AudioSessionMode.playback
        
        XCTAssertNotNil(recording)
        XCTAssertNotNil(playback)
    }
    
    // MARK: - Integration Tests with Mock
    
    func testMockServiceTranscriptionFlow() async throws {
        let transcriptions = ["The", "The quick", "The quick brown", "The quick brown fox"]
        let final = "The quick brown fox jumps over the lazy dog"
        
        mockService.simulatedTranscriptions = transcriptions
        mockService.simulatedFinalTranscription = final
        
        var allTranscriptions: [String] = []
        let allReceived = expectation(description: "All transcriptions received")
        allReceived.expectedFulfillmentCount = transcriptions.count + 1 // Plus final
        
        mockService.currentTranscriptionPublisher
            .sink { text in
                allTranscriptions.append(text)
                allReceived.fulfill()
            }
            .store(in: &cancellables)
        
        mockService.finalTranscriptionPublisher
            .sink { text in
                allTranscriptions.append(text)
                allReceived.fulfill()
            }
            .store(in: &cancellables)
        
        try await mockService.startRecording(language: "English")
        
        await fulfillment(of: [allReceived], timeout: 2)
        
        XCTAssertEqual(allTranscriptions.dropLast(), transcriptions)
        XCTAssertEqual(allTranscriptions.last, final)
    }
}