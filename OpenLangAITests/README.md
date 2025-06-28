# OpenLangAI Test Suite

This directory contains the unit tests for the OpenLangAI application, with a focus on the OnboardingViewModel.

## Test Structure

### Main Test Files

1. **OnboardingViewModelTests.swift**
   - Basic unit tests for OnboardingViewModel
   - Tests core functionality without dependency injection
   - Good for quick validation of basic behavior

2. **OnboardingViewModelDITests.swift**
   - Comprehensive tests using dependency injection
   - Uses mock implementations for better test isolation
   - Recommended for thorough testing

### Supporting Files

1. **Mocks/MockDependencies.swift**
   - Mock implementations for external dependencies
   - Protocol definitions for dependency injection
   - Testable version of OnboardingViewModel

2. **TestConfiguration.swift**
   - Common test configuration and helpers
   - Async test utilities
   - Custom assertions for better testing

## Test Coverage

The test suite covers:

### ✅ API Key Validation
- Successful validation flow
- Validation failure handling
- Keychain save failures
- Network error scenarios
- Empty and invalid key handling

### ✅ Navigation
- Step progression (language → level → API key)
- Back navigation
- Direct step navigation

### ✅ State Management
- Language selection persistence
- Level selection persistence
- API key state management
- Validation state transitions

### ✅ Error Handling
- Keychain errors
- Network errors
- Validation errors
- Error state display

### ✅ User Interactions
- Clipboard paste functionality
- Skip API key flow
- Complete onboarding flow

### ✅ Edge Cases
- Empty API keys
- Very long API keys
- Concurrent validation attempts
- Memory management (no retain cycles)

## Running Tests

### Command Line
```bash
# Run all tests
xcodebuild test -scheme OpenLangAI -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test file
xcodebuild test -scheme OpenLangAI -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:OpenLangAITests/OnboardingViewModelDITests
```

### Xcode
1. Open the project in Xcode
2. Press `Cmd+U` to run all tests
3. Or click the diamond icon next to individual test methods

## Writing New Tests

### Basic Test Structure
```swift
func testFeatureName() async {
    // Setup
    let viewModel = TestableOnboardingViewModel(...)
    
    // Action
    await viewModel.someMethod()
    
    // Verify
    XCTAssertEqual(viewModel.someProperty, expectedValue)
}
```

### Using Mocks
```swift
func testWithMocks() async {
    // Setup mocks
    let mockKeychain = MockKeychainHelperDI.self
    mockKeychain.shouldThrowOnSave = true
    
    let viewModel = TestableOnboardingViewModel(
        keychainHelper: mockKeychain
    )
    
    // Test error handling
    await viewModel.validateAndComplete()
    XCTAssertTrue(viewModel.showError)
}
```

## Best Practices

1. **Use Dependency Injection**: Prefer `TestableOnboardingViewModel` with mocks
2. **Test Async Code**: Use `async/await` and proper expectations
3. **Clean State**: Always reset mocks and UserDefaults in `tearDown`
4. **Test Edge Cases**: Don't just test happy paths
5. **Use Descriptive Names**: Test method names should describe what is being tested

## Future Improvements

1. **UI Tests**: Add XCUITest for end-to-end testing
2. **Performance Tests**: Add more performance benchmarks
3. **Snapshot Tests**: Consider adding snapshot tests for UI validation
4. **Code Coverage**: Aim for >80% code coverage
5. **CI Integration**: Set up automated test runs on pull requests