import SwiftUI
import PersistenceKit

struct SessionView: View {
    @StateObject private var viewModel = SessionViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Transcript area
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(viewModel.transcript) { entry in
                                TranscriptBubble(entry: entry, showTranslation: viewModel.showTranslation)
                                    .id(entry.id)
                            }
                            
                            if !viewModel.currentUserText.isEmpty {
                                TranscriptBubble(
                                    entry: TranscriptEntry(
                                        text: viewModel.currentUserText,
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
                    .onChange(of: viewModel.transcript.count) { _ in
                        withAnimation {
                            proxy.scrollTo(viewModel.transcript.last?.id, anchor: .bottom)
                        }
                    }
                }
                .background(Color(UIColor.systemGroupedBackground))
                
                // Controls area
                VStack(spacing: 20) {
                    // Error message display
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Translation toggle
                    Toggle(Constants.Text.Session.showTranslations, isOn: $viewModel.showTranslation)
                        .padding(.horizontal)
                    
                    // Main speak button
                    Button(action: {
                        viewModel.toggleRecording()
                    }) {
                        ZStack {
                            Circle()
                                .fill(viewModel.isRecording ? Color.red : Color.blue)
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: viewModel.isRecording ? Constants.SFSymbols.pauseFill : Constants.SFSymbols.micFill)
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(viewModel.isProcessing)
                    .scaleEffect(viewModel.isRecording ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: Constants.AnimationDurations.short).repeatForever(autoreverses: true), value: viewModel.isRecording)
                    
                    Text(viewModel.isRecording ? Constants.Text.Session.listening : Constants.Text.Session.tapToSpeak)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(UIColor.systemBackground))
            }
            .navigationTitle("\(viewModel.selectedLanguage.flag) \(Constants.Text.Tabs.practice)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(Constants.Text.Session.endSession) {
                        viewModel.endSession()
                    }
                }
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .sheet(isPresented: $viewModel.showingRecap) {
            if let conversation = viewModel.currentConversation {
                SessionRecapView(conversation: conversation)
            }
        }
    }
}

// MARK: - TranscriptBubble View (Purely Presentational)
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

// MARK: - Preview
struct SessionView_Previews: PreviewProvider {
    static var previews: some View {
        SessionView()
    }
}