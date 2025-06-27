import SwiftUI
import Speech
import AVFoundation
import OpenAIClientKit
import PersistenceKit

struct SessionView: View {
    @State private var isRecording = false
    @State private var transcript: [TranscriptEntry] = []
    @State private var currentUserText = ""
    @State private var showTranslation = false
    @State private var isProcessing = false
    @State private var showingRecap = false
    @State private var currentConversation: Conversation?
    
    // Speech recognition
    @State private var speechRecognizer: SFSpeechRecognizer?
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    
    // Error handling
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // User preferences
    private let selectedLanguage = Language(rawValue: UserDefaults.standard.string(forKey: "selectedLanguage") ?? "Spanish") ?? .spanish
    private let userLevel = UserDefaults.standard.string(forKey: "userLevel") ?? "beginner"
    private let selectedProvider = LLMProvider(rawValue: UserDefaults.standard.string(forKey: "selectedProvider") ?? "") ?? .chatGPT
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Transcript area
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(transcript) { entry in
                                TranscriptBubble(entry: entry, showTranslation: showTranslation)
                                    .id(entry.id)
                            }
                            
                            if !currentUserText.isEmpty {
                                TranscriptBubble(
                                    entry: TranscriptEntry(
                                        text: currentUserText,
                                        translation: nil,
                                        isUser: true,
                                        timestamp: Date()
                                    ),
                                    showTranslation: false
                                )
                                .opacity(0.7)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: transcript.count) { _ in
                        withAnimation {
                            proxy.scrollTo(transcript.last?.id, anchor: .bottom)
                        }
                    }
                }
                .background(Color(UIColor.systemGroupedBackground))
                
                // Controls area
                VStack(spacing: 20) {
                    // Translation toggle
                    Toggle("Show translations", isOn: $showTranslation)
                        .padding(.horizontal)
                    
                    // Main speak button
                    Button(action: toggleRecording) {
                        ZStack {
                            Circle()
                                .fill(isRecording ? Color.red : Color.blue)
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: isRecording ? "pause.fill" : "mic.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(isProcessing)
                    .scaleEffect(isRecording ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.3).repeatForever(autoreverses: true), value: isRecording)
                    
                    Text(isRecording ? "Listening..." : "Tap to speak")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(UIColor.systemBackground))
            }
            .navigationTitle("\(selectedLanguage.flag) Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("End Session") {
                        endSession()
                    }
                }
            }
        }
        .onAppear {
            setupSpeechRecognition()
            startNewConversation()
        }
        .onDisappear {
            stopRecording()
            if let conversation = currentConversation {
                PersistenceController.shared.endConversation(conversation)
            }
        }
        .sheet(isPresented: $showingRecap) {
            if let conversation = currentConversation {
                SessionRecapView(conversation: conversation)
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func setupSpeechRecognition() {
        // Request permissions
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: self.getLocaleIdentifier()))
                case .denied:
                    self.errorMessage = "Speech recognition permission denied. Please enable it in Settings > Privacy > Speech Recognition."
                    self.showingError = true
                case .restricted:
                    self.errorMessage = "Speech recognition is restricted on this device."
                    self.showingError = true
                case .notDetermined:
                    break
                @unknown default:
                    break
                }
            }
        }
        
        AVAudioApplication.requestRecordPermission { granted in
            if !granted {
                DispatchQueue.main.async {
                    self.errorMessage = "Microphone permission denied. Please enable it in Settings > Privacy > Microphone."
                    self.showingError = true
                }
            }
        }
    }
    
    private func getLocaleIdentifier() -> String {
        switch selectedLanguage {
        case .spanish: return "es-ES"
        case .french: return "fr-FR"
        case .japanese: return "ja-JP"
        case .italian: return "it-IT"
        case .portuguese: return "pt-PT"
        }
    }
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition is not available. Please check your language settings or try again later."
            showingError = true
            return
        }
        
        // Reset the audio engine and recognition task
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Failed to set up audio session. Please check your microphone permissions."
            showingError = true
            return
        }
        
        // Create and configure the recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "Unable to create speech recognition request. Please try again."
            showingError = true
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        
        // Configure the audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        // Start the recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                let transcription = result.bestTranscription.formattedString
                DispatchQueue.main.async { [self] in
                    self.currentUserText = transcription
                }
                
                if result.isFinal {
                    DispatchQueue.main.async { [self] in
                        self.stopRecording()
                        self.processUserInput(transcription)
                    }
                }
            }
            
            if let error = error {
                DispatchQueue.main.async { [self] in
                    self.stopRecording()
                    // Handle specific speech recognition errors
                    if let nsError = error as NSError? {
                        switch nsError.code {
                        case 203: // No speech detected
                            self.errorMessage = "No speech detected. Please speak clearly into the microphone."
                        case 216: // Audio engine error
                            self.errorMessage = "Audio recording error. Please try again."
                        case 1110: // Network error
                            self.errorMessage = "Network error during speech recognition. Please check your connection."
                        default:
                            self.errorMessage = "Speech recognition error: \(error.localizedDescription)"
                        }
                        self.showingError = true
                    }
                }
            }
        }
        
        // Start the audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            currentUserText = ""
        } catch {
            errorMessage = "Failed to start audio recording: \(error.localizedDescription)"
            showingError = true
            stopRecording()
        }
    }
    
    private func stopRecording() {
        isRecording = false
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    private func processUserInput(_ text: String) {
        guard !text.isEmpty else { return }
        
        isProcessing = true
        
        // Add user message to transcript and Core Data
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
            _ = PersistenceController.shared.addMessage(
                to: conversation,
                text: text,
                isUser: true
            )
        }
        
        // Get AI response
        Task {
            do {
                let response = try await LLMClient.shared.sendMessage(
                    text,
                    provider: selectedProvider,
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
                        _ = PersistenceController.shared.addMessage(
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
                    isProcessing = false
                    handleError(error)
                }
            }
        }
    }
    
    private func speakText(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: getLocaleIdentifier())
        utterance.rate = 0.5
        
        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
    }
    
    private func startNewConversation() {
        currentConversation = PersistenceController.shared.createConversation(
            language: selectedLanguage.rawValue,
            userLevel: userLevel
        )
    }
    
    private func endSession() {
        stopRecording()
        if let conversation = currentConversation {
            PersistenceController.shared.endConversation(conversation)
            showingRecap = true
        }
    }
    
    private func handleError(_ error: Error) {
        // Handle specific error types with user-friendly messages
        if let openAIError = error as? OpenAIError {
            switch openAIError {
            case .missingAPIKey:
                errorMessage = "API key is missing. Please add your API key in Settings."
            case .invalidAPIKey:
                errorMessage = "Invalid API key. Please check your API key in Settings."
            case .rateLimitExceeded:
                errorMessage = "Rate limit exceeded. Please wait a moment and try again."
            case .serverError:
                errorMessage = "Server error. Please try again later."
            case .invalidResponse, .invalidResponseFormat:
                errorMessage = "Received an invalid response. Please try again."
            case .apiError(let message):
                errorMessage = "API Error: \(message)"
            case .unknownError(let statusCode):
                errorMessage = "An unexpected error occurred (code: \(statusCode)). Please try again."
            case .invalidURL:
                errorMessage = "Configuration error. Please contact support."
            }
        } else if let llmError = error as? LLMError {
            switch llmError {
            case .providerNotImplemented(let provider):
                errorMessage = "\(provider) is not yet available. Please select ChatGPT in Settings."
            }
        } else if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet:
                errorMessage = "No internet connection. Please check your network settings."
            case .timedOut:
                errorMessage = "Request timed out. Please check your internet connection and try again."
            case .cannotFindHost, .cannotConnectToHost:
                errorMessage = "Cannot connect to the server. Please check your internet connection."
            default:
                errorMessage = "Network error: \(urlError.localizedDescription)"
            }
        } else {
            // Generic error handling
            errorMessage = "An unexpected error occurred: \(error.localizedDescription)"
        }
        
        showingError = true
    }
}

struct TranscriptEntry: Identifiable {
    let id = UUID()
    let text: String
    let translation: String?
    let isUser: Bool
    let timestamp: Date
}

struct TranscriptBubble: View {
    let entry: TranscriptEntry
    let showTranslation: Bool
    
    var body: some View {
        HStack {
            if entry.isUser { Spacer() }
            
            VStack(alignment: entry.isUser ? .trailing : .leading, spacing: 4) {
                Text(entry.text)
                    .padding(12)
                    .background(entry.isUser ? Color.blue : Color(UIColor.secondarySystemBackground))
                    .foregroundColor(entry.isUser ? .white : .primary)
                    .cornerRadius(16)
                
                if showTranslation, let translation = entry.translation {
                    Text(translation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: entry.isUser ? .trailing : .leading)
            
            if !entry.isUser { Spacer() }
        }
    }
}

struct SessionView_Previews: PreviewProvider {
    static var previews: some View {
        SessionView()
    }
}