# Retry

Retry is a flexible and configurable utility for handling retries of asynchronous operations in Swift. It provides a clean and type-safe way to implement retry logic with support for different backoff strategies, logging, and error handling.

## Features

- 🔄 Configurable retry attempts
- ⏰ Multiple backoff strategies (fixed, exponential, custom)
- 📝 Built-in logging support
- ⚡️ Async/await support
- 🛡️ Type-safe error handling
- ⚙️ Customizable delay intervals

## Installation

Add the Retry utility to your Swift package or project:

```swift
dependencies: [
    .package(url: "[your-repository-url](https://github.com/1amageek/SwiftRetry.git)", from: "1.0.0")
]
```

## Basic Usage

### Simple Retry

```swift
let result = try await Retry.attempt(maxAttempts: 3) {
    try await someAsyncOperation()
}
```

### Retry with Configuration

```swift
let config = Retry.Configuration(
    maxAttempts: 5,
    delay: 1.0,
    backoffStrategy: .exponential(factor: 2),
    enableLogging: true
)

let result = try await Retry.attempt(
    configuration: config,
    logger: logger
) {
    try await someAsyncOperation()
}
```

## Configuration Options

### Configuration Structure

```swift
public struct Configuration {
    let maxAttempts: Int
    let delay: TimeInterval?
    let backoffStrategy: BackoffStrategy
    let enableLogging: Bool
}
```

### Backoff Strategies

1. **Fixed Delay**
   ```swift
   .fixed // Uses the same delay between each attempt
   ```

2. **Exponential Backoff**
   ```swift
   .exponential(factor: 2) // Doubles the delay after each attempt
   ```

3. **Custom Strategy**
   ```swift
   .custom { attempt in
       // Return custom delay for each attempt
       Double(attempt) * 0.5
   }
   ```

## Error Handling

Retry provides a structured error type that includes detailed information about the retry process:

```swift
public struct Error: Swift.Error {
    let attempts: Int         // Number of attempts made
    let maxAttempts: Int      // Maximum attempts allowed
    let underlyingError: Error // Original error that caused the failure
}
```

## Logging

Retry integrates with Swift's `Logger` for structured logging:

```swift
import Logging

let logger = Logger(label: "com.example.retry")
try await Retry.attempt(
    configuration: .default,
    logger: logger
) {
    // Your async operation
}
```

## Advanced Examples

### Network Request with Retry

```swift
func fetchData() async throws -> Data {
    let config = Retry.Configuration(
        maxAttempts: 3,
        delay: 2.0,
        backoffStrategy: .exponential(factor: 2)
    )
    
    return try await Retry.attempt(configuration: config) {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
```

### Database Operation with Custom Backoff

```swift
func saveToDatabase() async throws {
    let config = Retry.Configuration(
        maxAttempts: 5,
        delay: 1.0,
        backoffStrategy: .custom { attempt in
            // Implement custom delay logic
            min(Double(attempt) * 2.0, 10.0)
        }
    )
    
    try await Retry.attempt(configuration: config) {
        try await database.save()
    }
}
```

## Best Practices

1. **Choose Appropriate Retry Counts**
   - Consider the operation's nature and criticality
   - Avoid excessive retries for operations unlikely to succeed

2. **Configure Suitable Delays**
   - Use longer delays for external service calls
   - Keep delays shorter for local operations

3. **Use Exponential Backoff**
   - Recommended for network operations
   - Helps prevent overwhelming services

4. **Enable Logging in Production**
   - Helps track retry patterns
   - Aids in debugging and monitoring

5. **Handle Errors Appropriately**
   - Check `Retry.Error` for attempt counts
   - Inspect underlying errors for root causes

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

