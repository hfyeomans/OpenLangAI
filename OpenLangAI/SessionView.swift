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
    
    // User preferences
    private let selectedLanguage = Language(rawValue: UserDefaults.standard.string(forKey: "selectedLanguage") ?? "Spanish") ?? .spanish
    private let userLevel = UserDefaults.standard.string(forKey: "userLevel") ?? "beginner"
    
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
    }
    
    private func setupSpeechRecognition() {
        // Request permissions
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: getLocaleIdentifier()))
                default:
                    // Handle permission denied
                    break
                }
            }
        }
        
        AVAudioApplication.requestRecordPermission { granted in
            if !granted {
                print("Microphone permission denied")
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
            print("Speech recognition not available")
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
            print("Audio session setup failed: \(error)")
            return
        }
        
        // Create and configure the recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("Unable to create recognition request")
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
                print("Recognition error: \(error)")
                DispatchQueue.main.async { [self] in
                    self.stopRecording()
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
            print("Audio engine failed to start: \(error)")
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
                    // Handle error
                    isProcessing = false
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