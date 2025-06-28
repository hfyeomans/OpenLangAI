import Foundation
import AVFoundation
import Speech
import Combine

// MARK: - AudioService Protocol

@MainActor
protocol AudioServiceProtocol: AnyObject {
    // Publishers
    var isRecording: Bool { get }
    var isRecordingPublisher: AnyPublisher<Bool, Never> { get }
    var currentTranscriptionPublisher: AnyPublisher<String, Never> { get }
    var finalTranscriptionPublisher: AnyPublisher<String, Never> { get }
    var errorPublisher: AnyPublisher<Error, Never> { get }
    var speechCompletionPublisher: AnyPublisher<Void, Never> { get }
    
    // Methods
    func requestPermissions() async -> Bool
    func startRecording(language: String) async throws
    func stopRecording() async
    func speakText(_ text: String, language: String) async
    func configureAudioSession(mode: AudioSessionMode) throws
}

// MARK: - AudioSessionMode

enum AudioSessionMode {
    case recording
    case playback
}

// MARK: - AudioService Errors

enum AudioServiceError: LocalizedError {
    case permissionDenied
    case speechRecognitionNotAvailable
    case audioEngineError(Error)
    case recognitionError(Error)
    case audioSessionError(Error)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone or speech recognition permission denied"
        case .speechRecognitionNotAvailable:
            return "Speech recognition is not available on this device"
        case .audioEngineError(let error):
            return "Audio engine error: \(error.localizedDescription)"
        case .recognitionError(let error):
            return "Recognition error: \(error.localizedDescription)"
        case .audioSessionError(let error):
            return "Audio session error: \(error.localizedDescription)"
        }
    }
}

// MARK: - AudioService Implementation

@MainActor
final class AudioService: NSObject, AudioServiceProtocol {
    
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
    
    // MARK: - Private Properties
    
    private let audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        speechSynthesizer.delegate = self
    }
    
    // MARK: - Permission Management
    
    func requestPermissions() async -> Bool {
        let speechStatus = await requestSpeechPermission()
        let micStatus = await requestMicrophonePermission()
        return speechStatus && micStatus
    }
    
    private func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    
    // MARK: - Recording Management
    
    func startRecording(language: String) async throws {
        // Stop any ongoing recording
        await stopRecording()
        
        // Check permissions
        guard await requestPermissions() else {
            throw AudioServiceError.permissionDenied
        }
        
        // Configure audio session
        try configureAudioSession(mode: .recording)
        
        // Setup speech recognizer with language
        let locale = Locale(identifier: getLocaleIdentifier(for: language))
        speechRecognizer = SFSpeechRecognizer(locale: locale)
        
        guard let speechRecognizer = speechRecognizer,
              speechRecognizer.isAvailable else {
            throw AudioServiceError.speechRecognitionNotAvailable
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw AudioServiceError.speechRecognitionNotAvailable
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        
        // Configure audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Install tap on audio input
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            self?.handleRecognitionResult(result, error: error)
        }
        
        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
            _isRecording = true
        } catch {
            await stopRecording()
            throw AudioServiceError.audioEngineError(error)
        }
    }
    
    func stopRecording() async {
        _isRecording = false
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
    }
    
    // MARK: - Speech Synthesis
    
    func speakText(_ text: String, language: String) async {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: getLocaleIdentifier(for: language))
        utterance.rate = 0.5
        
        speechSynthesizer.speak(utterance)
    }
    
    // MARK: - Audio Session Configuration
    
    func configureAudioSession(mode: AudioSessionMode) throws {
        let session = AVAudioSession.sharedInstance()
        
        do {
            switch mode {
            case .recording:
                try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
                try session.setActive(true, options: .notifyOthersOnDeactivation)
            case .playback:
                try session.setCategory(.playback, mode: .default)
                try session.setActive(true, options: .notifyOthersOnDeactivation)
            }
        } catch {
            throw AudioServiceError.audioSessionError(error)
        }
    }
    
    // MARK: - Private Methods
    
    private func handleRecognitionResult(_ result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            errorSubject.send(AudioServiceError.recognitionError(error))
            Task { await stopRecording() }
            return
        }
        
        guard let result = result else { return }
        
        let transcription = result.bestTranscription.formattedString
        currentTranscriptionSubject.send(transcription)
        
        if result.isFinal {
            finalTranscriptionSubject.send(transcription)
            Task { await stopRecording() }
        }
    }
    
    private func getLocaleIdentifier(for language: String) -> String {
        switch language {
        case "English": return "en-US"
        case "Spanish": return "es-ES"
        case "French": return "fr-FR"
        case "German": return "de-DE"
        case "Italian": return "it-IT"
        case "Portuguese": return "pt-BR"
        case "Chinese": return "zh-CN"
        case "Japanese": return "ja-JP"
        case "Korean": return "ko-KR"
        default: return "en-US"
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension AudioService: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        speechCompletionSubject.send(())
    }
}