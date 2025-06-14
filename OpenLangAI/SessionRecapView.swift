import SwiftUI
import PersistenceKit
import AVFoundation

struct SessionRecapView: View {
    let conversation: Conversation
    @State private var extractedVocabulary: [VocabularyItem] = []
    @State private var confidenceScore: Double = 0.0
    @State private var isProcessingVocabulary = true
    @Environment(\.dismiss) private var dismiss
    
    private let synthesizer = AVSpeechSynthesizer()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Session Summary
                    SessionSummaryCard(
                        duration: conversation.duration,
                        messageCount: conversation.messageArray.count,
                        language: conversation.language ?? "Unknown"
                    )
                    
                    // Performance Metrics
                    PerformanceCard(confidenceScore: confidenceScore)
                    
                    // Extracted Vocabulary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("New Vocabulary")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if isProcessingVocabulary {
                            ProgressView("Extracting vocabulary...")
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if extractedVocabulary.isEmpty {
                            Text("No new vocabulary items found")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            ForEach(extractedVocabulary, id: \.id) { item in
                                VocabularyCard(item: item) {
                                    speakWord(item.word ?? "")
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Continue Learning Button
                    Button(action: scheduleReview) {
                        Label("Schedule Daily Review", systemImage: "bell.badge")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding()
                }
            }
            .navigationTitle("Session Recap")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            extractVocabulary()
            calculateConfidence()
        }
    }
    
    private func extractVocabulary() {
        // In a real implementation, this would analyze the conversation
        // and extract new/difficult words using NLP or the LLM
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // For now, simulate extraction
            let sampleWords = [
                ("hola", "hello", "Common greeting"),
                ("gracias", "thank you", "Expression of gratitude"),
                ("por favor", "please", "Polite request")
            ]
            
            for (word, translation, definition) in sampleWords.prefix(5) {
                let item = PersistenceController.shared.addVocabularyItem(
                    to: conversation,
                    word: word,
                    translation: translation,
                    definition: definition
                )
                extractedVocabulary.append(item)
            }
            
            isProcessingVocabulary = false
        }
    }
    
    private func calculateConfidence() {
        // Calculate based on conversation flow, corrections needed, etc.
        // For now, simulate with a random score
        withAnimation(.easeInOut(duration: 1.0)) {
            confidenceScore = Double.random(in: 0.6...0.95)
        }
    }
    
    private func speakWord(_ word: String) {
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = AVSpeechSynthesisVoice(language: getLocaleIdentifier())
        utterance.rate = 0.4 // Slower for learning
        synthesizer.speak(utterance)
    }
    
    private func getLocaleIdentifier() -> String {
        switch conversation.language {
        case "Spanish": return "es-ES"
        case "French": return "fr-FR"
        case "Japanese": return "ja-JP"
        case "Italian": return "it-IT"
        case "Portuguese": return "pt-PT"
        default: return "en-US"
        }
    }
    
    private func scheduleReview() {
        // Schedule notification for review
        // For now, just mark items for review
        extractedVocabulary.forEach { item in
            item.scheduleNextReview()
        }
        PersistenceController.shared.save()
        dismiss()
    }
}

struct SessionSummaryCard: View {
    let duration: TimeInterval
    let messageCount: Int
    let language: String
    
    var body: some View {
        VStack(spacing: 12) {
            Text("Session Summary")
                .font(.headline)
            
            HStack(spacing: 30) {
                VStack {
                    Image(systemName: "clock.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("\(Int(duration / 60)) min")
                        .font(.caption)
                }
                
                VStack {
                    Image(systemName: "message.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                    Text("\(messageCount) messages")
                        .font(.caption)
                }
                
                VStack {
                    Text(flagForLanguage(language))
                        .font(.title2)
                    Text(language)
                        .font(.caption)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func flagForLanguage(_ language: String) -> String {
        switch language {
        case "Spanish": return "🇪🇸"
        case "French": return "🇫🇷"
        case "Japanese": return "🇯🇵"
        case "Italian": return "🇮🇹"
        case "Portuguese": return "🇵🇹"
        default: return "🌍"
        }
    }
}

struct PerformanceCard: View {
    let confidenceScore: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance")
                .font(.headline)
            
            HStack {
                Text("Confidence")
                Spacer()
                Text("\(Int(confidenceScore * 100))%")
                    .fontWeight(.semibold)
            }
            
            ProgressView(value: confidenceScore)
                .tint(colorForScore(confidenceScore))
            
            Text(feedbackForScore(confidenceScore))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func colorForScore(_ score: Double) -> Color {
        if score >= 0.8 { return .green }
        if score >= 0.6 { return .orange }
        return .red
    }
    
    private func feedbackForScore(_ score: Double) -> String {
        if score >= 0.8 { return "Excellent! You're making great progress!" }
        if score >= 0.6 { return "Good job! Keep practicing to improve fluency." }
        return "Keep going! Practice makes perfect."
    }
}

struct VocabularyCard: View {
    let item: VocabularyItem
    let onSpeak: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.word ?? "")
                    .font(.headline)
                
                if let translation = item.translation {
                    Text(translation)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let definition = item.definition {
                    Text(definition)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: onSpeak) {
                Image(systemName: "speaker.wave.2.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(10)
    }
}

struct SessionRecapView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock conversation for preview
        let context = PersistenceController.shared.viewContext
        let conversation = Conversation(context: context)
        conversation.language = "Spanish"
        conversation.startTime = Date().addingTimeInterval(-300) // 5 minutes ago
        
        return SessionRecapView(conversation: conversation)
    }
}