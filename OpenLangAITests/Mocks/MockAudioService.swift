import Foundation
import Combine
@testable import OpenLangAI

// MARK: - MockAudioService

class MockAudioService: AudioServiceProtocol {
    
    // MARK: - Test Control Properties
    
    var shouldFailPermissions = false
    var shouldFailStartRecording = false
    var simulatedPermissionGranted = true
    var simulatedTranscriptions: [String] = []
    var simulatedFinalTranscription: String?
    var simulatedError: Error?
    var startRecordingCallCount = 0
    var stopRecordingCallCount = 0
    var speakTextCallCount = 0
    var lastSpokenText: String?
    var lastSpokenLanguage: String?
    var lastRecordingLanguage: String?
    
    // MARK: - Publishers
    
    @Published private var _isRecording: Bool = false
    var isRecording: Bool { _isRecording }
    var isRecordingPublisher: AnyPublisher<Bool, Never> {
        $_isRecording.eraseToAnyPublisher()
    }
    
    private let currentTranscriptionSubject = PassthroughSubject<String, Never>()
    var currentTranscriptionPublisher: AnyPublisher<String, Never> {
        currentTranscriptionSubject.eraseToAnyPublisher()
    }
    
    private let finalTranscriptionSubject = PassthroughSubject<String, Never>()
    var finalTranscriptionPublisher: AnyPublisher<String, Never> {
        finalTranscriptionSubject.eraseToAnyPublisher()
    }
    
    private let errorSubject = PassthroughSubject<Error, Never>()
    var errorPublisher: AnyPublisher<Error, Never> {
        errorSubject.eraseToAnyPublisher()
    }
    
    private let speechCompletionSubject = PassthroughSubject<Void, Never>()
    var speechCompletionPublisher: AnyPublisher<Void, Never> {
        speechCompletionSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Methods
    
    func requestPermissions() async -> Bool {
        if shouldFailPermissions {
            return false
        }
        return simulatedPermissionGranted
    }
    
    func startRecording(language: String) async throws {
        startRecordingCallCount += 1
        lastRecordingLanguage = language
        
        if shouldFailStartRecording {
            throw AudioServiceError.audioEngineError(NSError(domain: "MockError", code: 1, userInfo: nil))
        }
        
        if let error = simulatedError {
            throw error
        }
        
        _isRecording = true
        
        // Simulate transcription updates
        Task {
            for transcription in simulatedTranscriptions {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                currentTranscriptionSubject.send(transcription)
            }
            
            if let finalTranscription = simulatedFinalTranscription {
                try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 second
                finalTranscriptionSubject.send(finalTranscription)
                _isRecording = false
            }
        }
    }
    
    func stopRecording() async {
        stopRecordingCallCount += 1
        _isRecording = false
    }
    
    func speakText(_ text: String, language: String) async {
        speakTextCallCount += 1
        lastSpokenText = text
        lastSpokenLanguage = language
        
        // Simulate speech completion after a delay
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
            speechCompletionSubject.send(())
        }
    }
    
    func configureAudioSession(mode: AudioSessionMode) throws {
        // Mock implementation - no-op for tests
    }
    
    // MARK: - Test Helper Methods
    
    func simulateTranscription(_ text: String) {
        currentTranscriptionSubject.send(text)
    }
    
    func simulateFinalTranscription(_ text: String) {
        finalTranscriptionSubject.send(text)
        _isRecording = false
    }
    
    func simulateError(_ error: Error) {
        errorSubject.send(error)
        _isRecording = false
    }
    
    func reset() {
        shouldFailPermissions = false
        shouldFailStartRecording = false
        simulatedPermissionGranted = true
        simulatedTranscriptions = []
        simulatedFinalTranscription = nil
        simulatedError = nil
        startRecordingCallCount = 0
        stopRecordingCallCount = 0
        speakTextCallCount = 0
        lastSpokenText = nil
        lastSpokenLanguage = nil
        lastRecordingLanguage = nil
        _isRecording = false
    }
}