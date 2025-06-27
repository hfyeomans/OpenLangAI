# Phase 2: Provider-Specific API Key Management Plan

## Overview
Implement support for storing and managing separate API keys for each LLM provider (OpenAI, Claude, Gemini).

## Current State Analysis
- **Problem**: KeychainHelper uses hardcoded "OpenAI_API_Key" identifier
- **Impact**: Cannot store different API keys for different providers
- **Limitation**: All providers would share the same API key (impossible)

## Design Goals
1. Each provider has its own API key storage
2. Backward compatibility with existing OpenAI keys
3. Secure storage in iOS Keychain
4. Clear UI for managing multiple keys
5. Provider-specific validation

## Implementation Plan

### 1. Update KeychainHelper (SecureStoreKit)
```swift
// Current: 
static func save(_ key: String, sync: SyncPolicy)
static func load() -> String?

// New:
static func save(_ key: String, provider: LLMProvider, sync: SyncPolicy)
static func load(provider: LLMProvider) -> String?
static func delete(provider: LLMProvider)
```

### 2. Update LLMClient
- Modify to load provider-specific API keys
- Each provider client gets its own key
- Better error messages for missing keys

### 3. Update ContentView UI
- Show API key field based on selected provider
- Different placeholder text per provider
- Provider-specific validation messages
- Visual indication of which keys are saved

### 4. Migration Strategy
- Check for existing "OpenAI_API_Key"
- Migrate to new format "APIKey_ChatGPT"
- Maintain backward compatibility

## Test Strategy

### Unit Tests
1. Test saving/loading keys for each provider
2. Test migration from old format
3. Test deletion of provider-specific keys
4. Test error handling for missing keys

### Integration Tests
1. Test provider switching with different keys
2. Test API calls with correct keys
3. Test validation for each provider

### UI Tests
1. Test entering keys for each provider
2. Test visual feedback
3. Test error states

## Success Criteria
- [ ] Each provider can have its own API key
- [ ] Keys are securely stored in Keychain
- [ ] UI clearly shows which provider's key is being edited
- [ ] Existing OpenAI keys are migrated automatically
- [ ] All tests pass

## Risk Mitigation
- Backward compatibility ensures existing users aren't affected
- Migration happens automatically on first launch
- Clear error messages guide users to add missing keys