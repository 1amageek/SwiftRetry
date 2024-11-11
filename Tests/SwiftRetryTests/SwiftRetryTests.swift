import Foundation
import Testing
import Logging
@testable import SwiftRetry

@Test("Basic retry success on first attempt")
func testBasicRetrySuccess() async throws {
    var callCount = 0
    let result = try await Retry.run {
        callCount += 1
        return "success"
    }
    
    #expect(result == "success")
    #expect(callCount == 1)
}

@Test("Retry with failure and eventual success")
func testRetryWithEventualSuccess() async throws {
    var attempts = 0
    let result = try await Retry.run {
        attempts += 1
        if attempts < 2 {
            throw NSError(domain: "TestError", code: -1)
        }
        return "success"
    }
    
    #expect(result == "success")
    #expect(attempts == 2)
}

@Test("Retry exceeds max attempts")
func testRetryExceedsMaxAttempts() async throws {
    var attempts = 0
    
    do {
        _ = try await Retry.run {
            attempts += 1
            throw NSError(domain: "TestError", code: -1)
        }
    } catch let error as Retry.Error {
        #expect(error.attempts == 3)
        #expect(error.maxAttempts == 3)
        #expect(attempts == 3)
    }
}

@Test("Fixed delay retry configuration")
func testFixedDelayRetry() async throws {
    let startTime = Date()
    var attempts = 0
    
    let config = Retry.Configuration.withFixedDelay(
        maxAttempts: 2,
        delay: 0.1
    )
    
    do {
        _ = try await Retry.attempt(configuration: config) {
            attempts += 1
            throw NSError(domain: "TestError", code: -1)
        }
    } catch is Retry.Error {
        let duration = Date().timeIntervalSince(startTime)
        #expect(duration >= 0.1)
        #expect(attempts == 2)
    }
}

@Test("Exponential backoff retry configuration")
func testExponentialBackoffRetry() async throws {
    let startTime = Date()
    var attempts = 0
    
    let config = Retry.Configuration.withExponentialBackoff(
        maxAttempts: 3,
        initialDelay: 0.1,
        factor: 2.0
    )
    
    do {
        _ = try await Retry.attempt(configuration: config) {
            attempts += 1
            throw NSError(domain: "TestError", code: -1)
        }
    } catch is Retry.Error {
        let duration = Date().timeIntervalSince(startTime)
        #expect(duration >= 0.3)
        #expect(duration < 0.5)
        #expect(attempts == 3)
    }
}

@Test("Custom backoff strategy")
func testCustomBackoffStrategy() async throws {
    var attempts = 0
    let customStrategy = Retry.BackoffStrategy.custom { attempt in
        return Double(attempt) * 0.1
    }
    
    let config = Retry.Configuration(
        maxAttempts: 2,
        delay: 0.1,
        backoffStrategy: customStrategy
    )
    
    do {
        _ = try await Retry.attempt(configuration: config) {
            attempts += 1
            throw NSError(domain: "TestError", code: -1)
        }
    } catch is Retry.Error {
        #expect(attempts == 2)
    }
}

@Test("Error description contains correct information")
func testErrorDescription() async throws {
    let testError = NSError(domain: "TestError", code: -1, userInfo: [
        NSLocalizedDescriptionKey: "Test failure"
    ])
    
    do {
        _ = try await Retry.run {
            throw testError
        }
    } catch let error as Retry.Error {
        let description = error.errorDescription ?? ""
        #expect(description.contains("3 attempts"))
        #expect(description.contains("Test failure"))
    }
}
