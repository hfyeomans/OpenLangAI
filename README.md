# OpenLangAI

An immersive iOS language learning app that enables natural voice conversations with AI tutors. Practice Spanish, French, Japanese, Italian, or Portuguese through real-time speech recognition and AI-powered responses.

![iOS 18.5+](https://img.shields.io/badge/iOS-18.5+-blue.svg)
![Swift 5.0](https://img.shields.io/badge/Swift-5.0-orange.svg)
![OpenAI](https://img.shields.io/badge/OpenAI-GPT--4-green.svg)
![Tests](https://img.shields.io/badge/tests-passing-brightgreen.svg)

## 🌟 Key Features

### Core Functionality
- **🎙️ Voice Conversations**: Natural speech recognition in your target language
- **🤖 AI Language Tutor**: Context-aware responses from GPT-4
- **⚡ Rapid Feedback**: < 2 second response time for fluid conversations
- **🔊 Text-to-Speech**: Native pronunciation for all responses
- **📝 Live Transcripts**: See your conversation in real-time

### Learning Features
- **📚 Post-Session Recap**: Review vocabulary and track progress
- **🎯 Spaced Repetition**: Smart scheduling for vocabulary retention
- **📊 Progress Tracking**: Streaks, practice time, and performance metrics
- **🌍 5 Languages**: Spanish, French, Japanese, Italian, Portuguese
- **👥 Adaptive Levels**: Beginner and intermediate conversation modes

### Privacy & Security
- **🔐 Secure API Storage**: Keys stored in iOS Keychain
- **📱 On-Device Processing**: Speech recognition happens locally when possible
- **🚫 No Account Required**: Start learning immediately
- **💾 Local Data**: Your conversations stay on your device

### Recent Improvements (v1.1)
- **✅ Provider Selection**: Choose between available LLM providers
- **🔄 Persistent Settings**: Your provider choice is remembered
- **🚨 Error Handling**: Clear error messages guide you to solutions
- **🏷️ Coming Soon Labels**: Future providers clearly marked

## 📱 Screenshots

<details>
<summary>View Screenshots</summary>

1. **Onboarding** - Choose language, level, and add API key
2. **Session Screen** - Tap to speak and see real-time transcripts
3. **Post-Session Recap** - Review vocabulary with pronunciation
4. **Settings** - Manage API keys and preferences

</details>

## 🚀 Getting Started

### Prerequisites
- macOS with Xcode 16.0+
- iOS 18.5+ device or simulator (iPhone 16 Pro recommended)
- OpenAI API key ([Get one here](https://platform.openai.com/api-keys))
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) installed

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/yourusername/OpenLangAIStarter.git
cd OpenLangAIStarter
```

2. **Generate Xcode project**
```bash
xcodegen generate
```

3. **Open in Xcode**
```bash
open OpenLangAI.xcodeproj
```

4. **Build and run**
- Select your target device/simulator
- Press `Cmd + R` to build and run

### First Time Setup

1. **Launch the app** - You'll see the onboarding flow
2. **Select your target language** - Choose from 5 supported languages
3. **Choose your level** - Beginner or Intermediate
4. **Add your OpenAI API key** - Securely stored in Keychain
5. **Start practicing!** - Tap the microphone button to begin

## 🏗️ Architecture

### Project Structure
```
OpenLangAI/
├── project.yml                 # XcodeGen configuration
├── OpenLangAI/                # Main iOS app
│   ├── AppDelegate.swift      # App lifecycle
│   ├── OnboardingView.swift   # Initial setup flow
│   ├── SessionView.swift      # Main conversation interface
│   ├── SessionRecapView.swift # Post-session vocabulary
│   └── MainTabView.swift      # Tab navigation
└── Packages/                  # Modular frameworks
    ├── AudioPipelineKit/      # Audio recording (AVAudioEngine)
    ├── OpenAIClientKit/       # LLM integrations
    ├── SecureStoreKit/        # Keychain wrapper
    └── PersistenceKit/        # Core Data models
```

### Key Technologies
- **SwiftUI**: Modern declarative UI
- **Speech Framework**: Apple's on-device speech recognition
- **AVAudioEngine**: Low-latency audio capture
- **Core Data**: Local conversation storage
- **Combine**: Reactive programming
- **async/await**: Modern concurrency

### Data Models
- **Conversation**: Session metadata and relationships
- **Message**: Individual utterances with translations
- **UserProgress**: Streaks, practice time, statistics
- **VocabularyItem**: Words for spaced repetition

## 🔧 Configuration

### API Keys
API keys are stored securely in the iOS Keychain. To update your key:
1. Go to Settings tab
2. Select your LLM provider (currently only ChatGPT is available)
3. Enter your OpenAI API key
4. Tap "Save Key"

**Note**: Claude and Gemini providers show "(Coming Soon)" and are not yet functional.

### Supported Languages
Configure additional languages in `Language.swift`:
```swift
public enum Language: String, CaseIterable {
    case spanish = "Spanish"
    case french = "French"
    // Add more languages here
}
```

### Audio Settings
Audio capture is configured for optimal speech recognition:
- Sample Rate: 16kHz
- Format: Mono PCM
- Buffer Size: 1024 frames

## 🧪 Development

### Building from Source
```bash
# Install dependencies
brew install xcodegen

# Generate project
xcodegen generate

# Build
xcodebuild -project OpenLangAI.xcodeproj -scheme OpenLangAI -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

### Running Tests
```bash
xcodebuild test -project OpenLangAI.xcodeproj -scheme OpenLangAI -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.5'
```

Test targets include:
- `OpenLangAITests`: Main app tests
- `OpenAIClientKitTests`: LLM client tests
- `SecureStoreKitTests`: Keychain tests
### Caveats
- Make sure the OpenLangAI.xcdatamodeld file is included in your app target's "Copy Bundle Resources" build phase in Xcode.

### Debug Features
- Set `OPENLANGAI_DEBUG=1` in scheme environment variables
- View Core Data SQL: `-com.apple.CoreData.SQLDebug 1`
- Speech recognition logs: `-com.apple.speech.SpeechRecognitionDebug 1

## 🚦 Roadmap

### In Progress
- [x] Provider selection persistence (Phase 1 ✅)
- [x] Error handling improvements (Phase 1 ✅)
- [ ] Provider-specific API key management (Phase 2)
- [ ] Claude API integration (Phase 3)
- [ ] Gemini API integration (Phase 3)

### Near Term
- [ ] Translation support for beginners
- [ ] Real vocabulary extraction using NLP
- [ ] Push notifications for practice reminders

### Future
- [ ] iPad and Apple Watch apps
- [ ] Offline mode with downloaded lessons
- [ ] Group conversation sessions
- [ ] Grammar explanations
- [ ] Export conversation history

See [PROJECT_FILE.md](PROJECT_FILE.md#future-functionality) for full roadmap.

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Setup
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- OpenAI for GPT-4 API
- Apple for Speech and AVAudioEngine frameworks
- The iOS development community for inspiration

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/OpenLangAIStarter/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/OpenLangAIStarter/discussions)
- **Email**: support@openlangai.com

---

**Made with ❤️ for language learners everywhere**
