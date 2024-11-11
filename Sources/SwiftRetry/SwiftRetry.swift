import Foundation
import Logging

/// A utility for handling retries of asynchronous operations.
///
/// `Retry` provides a flexible way to retry asynchronous operations with configurable
/// retry attempts, delays, and backoff strategies. It also supports structured logging
/// of retry attempts and failures.
///
/// Basic usage:
/// ```swift
/// let result = try await Retry.run {
///     try await someAsyncOperation()
/// }
/// ```
///
/// Usage with custom configuration:
/// ```swift
/// let config = Retry.Configuration(
///     maxAttempts: 3,
///     delay: 1.0,
///     backoffStrategy: .exponential(factor: 2),
///     logger: logger
/// )
///
/// let result = try await Retry.attempt(configuration: config) {
///     try await someAsyncOperation()
/// }
/// ```
public struct Retry {
    /// Configuration options for retry behavior.
    public struct Configuration: Sendable {
        /// Maximum number of retry attempts
        public let maxAttempts: Int
        
        /// Delay between retry attempts in seconds
        public let delay: TimeInterval?
        
        /// Strategy for calculating delay between retries
        public let backoffStrategy: BackoffStrategy?
        
        /// Logger for retry operations
        public let logger: Logger?
        
        /// Whether to log retry attempts
        public let enableLogging: Bool
        
        /// Creates a new configuration with the specified parameters.
        /// - Parameters:
        ///   - maxAttempts: Maximum number of retry attempts (default: 3)
        ///   - delay: Delay between retry attempts in seconds (default: nil)
        ///   - backoffStrategy: Strategy for calculating delay between retries (default: nil)
        ///   - logger: Logger for retry operations (default: nil)
        ///   - enableLogging: Whether to log retry attempts (default: true)
        public init(
            maxAttempts: Int = 3,
            delay: TimeInterval? = nil,
            backoffStrategy: BackoffStrategy? = nil,
            logger: Logger? = nil,
            enableLogging: Bool = true
        ) {
            self.maxAttempts = maxAttempts
            self.delay = delay
            self.backoffStrategy = backoffStrategy
            self.logger = logger
            self.enableLogging = enableLogging
        }
        
        /// Default configuration with 3 attempts and no delay
        public static let `default` = Configuration()
        
        /// Creates a new configuration with the specified logger while maintaining other settings
        /// - Parameter logger: The logger to use for retry operations
        /// - Returns: A new configuration with the specified logger
        public func with(logger: Logger) -> Configuration {
            Configuration(
                maxAttempts: self.maxAttempts,
                delay: self.delay,
                backoffStrategy: self.backoffStrategy,
                logger: logger,
                enableLogging: self.enableLogging
            )
        }
    }
    
    /// Strategy for calculating delay between retries
    public enum BackoffStrategy: Sendable {
        /// Fixed delay between attempts
        case fixed
        
        /// Exponential backoff with a multiplier factor
        case exponential(factor: Double)
        
        /// Custom delay calculation
        case custom(@Sendable (Int) -> TimeInterval)
        
        /// Calculates the delay for a given attempt
        /// - Parameters:
        ///   - attempt: The current attempt number
        ///   - baseDelay: The base delay to use for calculations
        /// - Returns: The calculated delay in seconds
        func delay(forAttempt attempt: Int, baseDelay: TimeInterval) -> TimeInterval {
            switch self {
            case .fixed:
                return baseDelay
            case .exponential(let factor):
                return baseDelay * pow(factor, Double(attempt - 1))
            case .custom(let calculator):
                return calculator(attempt)
            }
        }
    }
    
    /// Error representing retry failure
    public struct Error: Swift.Error, LocalizedError {
        /// The number of attempts made
        public let attempts: Int
        
        /// The maximum number of attempts allowed
        public let maxAttempts: Int
        
        /// The final error that caused the retry to fail
        public let underlyingError: Swift.Error
        
        public var errorDescription: String? {
            "Operation failed after \(attempts) attempts (max: \(maxAttempts)). Last error: \(underlyingError.localizedDescription)"
        }
    }
    
    /// Executes an async operation with retry logic using default configuration
    /// - Parameter operation: The async operation to retry
    /// - Returns: The result of the successful operation
    /// - Throws: Retry.Error if all attempts fail
    public static func run<T: Sendable>(
        _ operation: @escaping () async throws -> T
    ) async throws -> T {
        try await attempt(configuration: .default, operation: operation)
    }
    
    /// Executes an async operation with retry logic
    /// - Parameters:
    ///   - configuration: Configuration for retry behavior
    ///   - operation: The async operation to retry
    /// - Returns: The result of the successful operation
    /// - Throws: Retry.Error if all attempts fail
    public static func attempt<T: Sendable>(
        configuration: Configuration = .default,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var attempt = 1
        var lastError: Swift.Error?
        
        while attempt <= configuration.maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                if configuration.enableLogging {
                    configuration.logger?.warning("Retry attempt failed", metadata: [
                        "attempt": .string("\(attempt)"),
                        "maxAttempts": .string("\(configuration.maxAttempts)"),
                        "error": .string(error.localizedDescription)
                    ])
                }
                
                if attempt < configuration.maxAttempts {
                    // Apply delay if configured
                    if let baseDelay = configuration.delay,
                       let strategy = configuration.backoffStrategy {
                        let delay = strategy.delay(
                            forAttempt: attempt,
                            baseDelay: baseDelay
                        )
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    }
                    attempt += 1
                    continue
                }
                
                if configuration.enableLogging {
                    configuration.logger?.error("Max retry attempts exceeded", metadata: [
                        "attempts": .string("\(attempt)"),
                        "maxAttempts": .string("\(configuration.maxAttempts)"),
                        "finalError": .string(error.localizedDescription)
                    ])
                }
                
                throw Error(
                    attempts: attempt,
                    maxAttempts: configuration.maxAttempts,
                    underlyingError: lastError ?? error
                )
            }
        }
        
        throw Error(
            attempts: attempt,
            maxAttempts: configuration.maxAttempts,
            underlyingError: lastError ?? NSError(domain: "RetryError", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Unexpected retry failure"
            ])
        )
    }
}

// MARK: - Convenience Configuration Factories

extension Retry.Configuration {
    /// Creates a configuration with exponential backoff
    /// - Parameters:
    ///   - maxAttempts: Maximum number of retry attempts (default: 3)
    ///   - initialDelay: Initial delay between attempts in seconds (default: 1.0)
    ///   - factor: Multiplier for exponential backoff (default: 2.0)
    ///   - logger: Optional logger for retry operations
    /// - Returns: A configuration with exponential backoff
    public static func withExponentialBackoff(
        maxAttempts: Int = 3,
        initialDelay: TimeInterval = 1.0,
        factor: Double = 2.0,
        logger: Logger? = nil
    ) -> Retry.Configuration {
        .init(
            maxAttempts: maxAttempts,
            delay: initialDelay,
            backoffStrategy: .exponential(factor: factor),
            logger: logger
        )
    }
    
    /// Creates a configuration with fixed delay
    /// - Parameters:
    ///   - maxAttempts: Maximum number of retry attempts (default: 3)
    ///   - delay: Fixed delay between attempts in seconds
    ///   - logger: Optional logger for retry operations
    /// - Returns: A configuration with fixed delay
    public static func withFixedDelay(
        maxAttempts: Int = 3,
        delay: TimeInterval,
        logger: Logger? = nil
    ) -> Retry.Configuration {
        .init(
            maxAttempts: maxAttempts,
            delay: delay,
            backoffStrategy: .fixed,
            logger: logger
        )
    }
}
