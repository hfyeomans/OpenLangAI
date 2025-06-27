# OpenLangAI Conversation Flow Debugging Guide

## Expected Behavior

When you tap the microphone button:
1. **Recording starts** - The button turns red and shows "Listening..."
2. **You speak** in any language (your native language or target language)
3. **Speech is recognized** and appears as text in the transcript
4. **AI responds** in your selected target language only
5. **Response is spoken** using the device's text-to-speech in the target language
6. **Conversation continues** naturally back and forth

## Common Issues and Solutions

### 1. Speech Recognition Not Working

**Symptoms**: 
- Nothing appears when you speak
- "Listening..." stays on but no text appears

**Check**:
- Microphone permissions granted in Settings > OpenLangAI
- Speech Recognition permissions granted
- Speaking clearly and not too far from device
- Internet connection (speech recognition may use cloud services)

**Debug Steps**:
1. Check Settings > Privacy & Security > Microphone > OpenLangAI ✓
2. Check Settings > Privacy & Security > Speech Recognition > OpenLangAI ✓
3. Try speaking louder or closer to the microphone
4. Check the language setting matches what you're speaking

### 2. AI Not Responding

**Symptoms**:
- Your speech appears but no AI response
- Error alerts appear

**Check**:
- Valid OpenAI API key entered in Settings
- Internet connection active
- Selected provider is ChatGPT (only implemented provider)

**Debug Steps**:
1. Go to Settings tab
2. Verify API key is entered
3. Tap "Test Connection" - should show "Successfully connected to OpenAI"
4. Check that ChatGPT is selected (not Claude or Gemini)

### 3. No Voice Response

**Symptoms**:
- AI text appears but doesn't speak

**Check**:
- Device not in silent mode
- Volume turned up
- Language has TTS support

**Debug Steps**:
1. Check device ringer switch (not silent)
2. Turn up volume
3. Test with a common language (Spanish, French) first

### 4. Wrong Language Response

**Symptoms**:
- AI responds in English instead of target language
- Mixed language responses

**Check**:
- Language selection in onboarding
- System prompt configuration

**What's Happening Behind the Scenes**:
```
You speak → "Hola, cómo estás?" 
↓
Speech Recognition → Converts to text
↓
Sent to ChatGPT with prompt: "You are a patient language tutor. Speak only in Spanish..."
↓
ChatGPT responds → "¡Hola! Estoy muy bien, gracias. ¿Y tú, cómo estás hoy?"
↓
Text-to-Speech → Speaks response in Spanish accent
```

## Testing the Flow

### Basic Test:
1. Select Spanish as target language
2. Enter valid OpenAI API key
3. Tap microphone button
4. Say "Hello" or "Hola"
5. Wait for Spanish response
6. Response should be spoken aloud

### Expected AI Behavior:
- **Beginner Level**: Simple responses, basic vocabulary
- **Intermediate Level**: More complex sentences, varied vocabulary
- **Always in Target Language**: Unless you explicitly ask for translation

## Current Implementation Details

- **Speech Recognition**: Uses Apple's Speech framework with device locale
- **LLM**: OpenAI GPT-4 with language tutor system prompt
- **Text-to-Speech**: AVSpeechSynthesizer with language-specific voice
- **Languages**: Spanish, French, Japanese, Italian, Portuguese

## Troubleshooting Commands

If the conversation flow isn't working, check these components:

1. **Microphone Permission**:
   ```swift
   AVAudioApplication.requestRecordPermission { granted in
       print("Microphone permission: \(granted)")
   }
   ```

2. **Speech Recognition Permission**:
   ```swift
   SFSpeechRecognizer.requestAuthorization { status in
       print("Speech recognition status: \(status)")
   }
   ```

3. **API Key Validation**:
   - Settings > Test Connection

4. **Language Setting**:
   - Check UserDefaults: "selectedLanguage"
   - Check UserDefaults: "selectedProvider"

## If Nothing Works

1. Force quit the app and restart
2. Check Xcode console for error messages
3. Verify all permissions in device Settings
4. Ensure strong internet connection
5. Try with a different language
6. Regenerate your OpenAI API key if needed