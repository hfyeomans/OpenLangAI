import Foundation
import XCTest
import Combine

// MARK: - Test Configuration

struct TestConfiguration {
    static let defaultTimeout: TimeInterval = 5.0
    static let shortTimeout: TimeInterval = 1.0
    static let longTimeout: TimeInterval = 10.0
    
    static let testAPIKey = "test-api-key-12345"
    static let invalidAPIKey = "invalid-key"
    
    static func setUp() {
        // Configure test environment
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
    }
    
    static func tearDown() {
        // Clean up test environment
        let keysToRemove = [
            "hasCompletedOnboarding",
            "selectedLanguage",
            "userLevel"
        ]
        
        keysToRemove.forEach { key in
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        UserDefaults.standard.synchronize()
    }
}

// MARK: - XCTest Extensions

extension XCTestCase {
    func waitForMainQueue() {
        let expectation = XCTestExpectation(description: "Main queue")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.1)
    }
    
    @MainActor
    func waitForAsync() async {
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
}

// MARK: - Async Test Helpers

extension XCTestCase {
    func asyncTest<T>(
        timeout: TimeInterval = TestConfiguration.defaultTimeout,
        _ block: @escaping () async throws -> T
    ) throws -> T {
        var result: Result<T, Error>?
        let expectation = XCTestExpectation(description: "Async operation")
        
        Task {
            do {
                let value = try await block()
                result = .success(value)
            } catch {
                result = .failure(error)
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: timeout)
        
        switch result {
        case .success(let value):
            return value
        case .failure(let error):
            throw error
        case .none:
            throw TestError.timeout
        }
    }
}

// MARK: - Test Errors

enum TestError: LocalizedError {
    case timeout
    case unexpectedNil
    case invalidState(String)
    
    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Async operation timed out"
        case .unexpectedNil:
            return "Unexpected nil value"
        case .invalidState(let message):
            return "Invalid state: \(message)"
        }
    }
}

// MARK: - Assertion Helpers

extension XCTestCase {
    func assertEventually(
        timeout: TimeInterval = TestConfiguration.shortTimeout,
        file: StaticString = #file,
        line: UInt = #line,
        _ condition: @escaping () -> Bool
    ) {
        let expectation = XCTestExpectation(description: "Condition met")
        
        let timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            if condition() {
                expectation.fulfill()
                timer.invalidate()
            }
        }
        
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        timer.invalidate()
        
        XCTAssertEqual(result, .completed, "Condition was not met within timeout", file: file, line: line)
    }
    
    @MainActor
    func assertPublished<T: Equatable>(
        _ publisher: Published<T>.Publisher,
        equals expectedValue: T,
        timeout: TimeInterval = TestConfiguration.shortTimeout,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let expectation = XCTestExpectation(description: "Published value matches")
        var cancellable: AnyCancellable?
        
        cancellable = publisher
            .sink { value in
                if value == expectedValue {
                    expectation.fulfill()
                    cancellable?.cancel()
                }
            }
        
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        cancellable?.cancel()
        
        XCTAssertEqual(result, .completed, "Published value did not match expected value within timeout", file: file, line: line)
    }
}