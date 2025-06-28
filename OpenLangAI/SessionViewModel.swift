import Foundation
import Combine
import OpenAIClientKit
import PersistenceKit
import AVFoundation

@MainActor
class SessionViewModel: ObservableObject {
    // MARK: - Published Properties (UI State)
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
    private let persistenceService: PersistenceServiceProtocol
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init(audioService: AudioServiceProtocol? = nil, persistenceService: PersistenceServiceProtocol? = nil) {
        self.audioService = audioService ?? AudioService()
        self.persistenceService = persistenceService ?? PersistenceService()
        self.selectedLanguage = Language(rawValue: UserDefaults.standard.selectedLanguage ?? Constants.Languages.spanish) ?? .spanish
        self.userLevel = UserDefaults.standard.userLevel ?? Constants.UserLevels.beginnerKey
        
        setupAudioServiceBindings()
    }
    
    // MARK: - Public Methods
    
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
            Task {
                try? await persistenceService.endConversation(conversation)
            }
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
            Task {
                try? await persistenceService.endConversation(conversation)
                await MainActor.run {
                    showingRecap = true
                }
            }
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
    
    private func processUserInput(_ text: String) {
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
            Task {
                _ = try? await persistenceService.addMessage(
                    to: conversation,
                    text: text,
                    isUser: true,
                    translation: nil
                )
            }
        }
        
        // Get AI response
        Task {
            await getAIResponse(for: text)
        }
    }
    
    private func getAIResponse(for userText: String) async {
        do {
            let response = try await LLMClient.shared.sendMessage(
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
                    Task {
                        _ = try? await persistenceService.addMessage(
                            to: conversation,
                            text: response,
                            isUser: false,
                            translation: nil
                        )
                    }
                }
                
                // Speak the response
                speakText(response)
            }
        } catch {
            await MainActor.run {
                errorMessage = Constants.Text.Session.errorPrefix + error.localizedDescription
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
        Task {
            do {
                currentConversation = try await persistenceService.createConversation(
                    language: selectedLanguage.rawValue,
                    userLevel: userLevel
                )
            } catch {
                errorMessage = "Failed to create conversation: \(error.localizedDescription)"
            }
        }
    }
    
}

// MARK: - TranscriptEntry Model
struct TranscriptEntry: Identifiable {
    let id = UUID()
    let text: String
    let translation: String?
    let isUser: Bool
    let timestamp: Date
}