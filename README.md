# Retry

A robust and flexible retry utility for Swift, providing type-safe retry logic for asynchronous operations. Simplify your error handling with configurable retry attempts, multiple backoff strategies, and comprehensive logging support. 🔄 ⚡️

## Features

- 🛡️ Type-safe retry configuration
- ⏰ Configurable delays and backoff strategies
- 📝 Structured logging support
- ⚡️ Modern async/await API
- 🔄 Multiple retry strategies out of the box
- 🎯 Easy-to-use convenience methods

## Installation

Add the dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/1amageek/SwiftRetry.git, from: "1.0.0")
]
```

## Quick Start

### Basic Usage

The simplest way to use Retry is with the `run` method:

```swift
let result = try await Retry.run {
    try await someAsyncOperation()
}
```

### Custom Configuration

For more control, use the `attempt` method with custom configuration:

```swift
let config = Retry.Configuration(
    maxAttempts: 5,
    delay: 1.0,
    backoffStrategy: .exponential(factor: 2),
    logger: logger
)

let result = try await Retry.attempt(configuration: config) {
    try await someAsyncOperation()
}
```

## Configuration

### Built-in Factory Methods

Retry provides convenient factory methods for common configurations:

```swift
// Exponential backoff
let exponentialConfig = Retry.Configuration.withExponentialBackoff(
    maxAttempts: 3,
    initialDelay: 1.0,
    factor: 2.0,
    logger: logger
)

// Fixed delay
let fixedConfig = Retry.Configuration.withFixedDelay(
    maxAttempts: 3,
    delay: 2.0,
    logger: logger
)
```

### Custom Configuration

Create a custom configuration with specific requirements:

```swift
let config = Retry.Configuration(
    maxAttempts: 3,
    delay: 1.0,
    backoffStrategy: .custom { attempt in
        Double(attempt) * 0.5
    },
    logger: logger,
    enableLogging: true
)
```

## Backoff Strategies

Retry supports three types of backoff strategies:

### Fixed Delay
```swift
.fixed // Uses the same delay between each attempt
```

### Exponential Backoff
```swift
.exponential(factor: 2.0) // Doubles the delay after each attempt
```

### Custom Strategy
```swift
.custom { attempt in
    // Custom delay calculation
    min(Double(attempt) * 0.5, 5.0)
}
```

## Logging Integration

Retry integrates with Swift's `Logger` for detailed retry monitoring:

```swift
import Logging

let logger = Logger(label: "com.example.retry")
let config = Retry.Configuration(
    maxAttempts: 3,
    delay: 1.0,
    backoffStrategy: .exponential(factor: 2),
    logger: logger,
    enableLogging: true
)
```

### Logging Output Example
```
warning: Retry attempt failed
    attempt: 1
    maxAttempts: 3
    error: The operation couldn't be completed

error: Max retry attempts exceeded
    attempts: 3
    maxAttempts: 3
    finalError: The operation couldn't be completed
```

## Error Handling

Retry provides structured error information through `Retry.Error`:

```swift
do {
    let result = try await Retry.run {
        try await someAsyncOperation()
    }
} catch let error as Retry.Error {
    print("Failed after \(error.attempts) attempts")
    print("Original error: \(error.underlyingError)")
}
```

## Best Practices

1. **Choose Appropriate Retry Counts**
   - Consider operation idempotency
   - Avoid excessive retries for unlikely-to-recover operations

2. **Configure Suitable Delays**
   - Use longer delays for external service calls
   - Consider exponential backoff for rate-limited APIs

3. **Enable Logging in Production**
   - Monitor retry patterns
   - Track operation reliability

4. **Use Type-Safe Configuration**
   - Leverage factory methods for common patterns
   - Create custom configurations for specific needs

## Examples

### Network Request with Retry

```swift
func fetchData() async throws -> Data {
    try await Retry.attempt(
        configuration: .withExponentialBackoff(
            maxAttempts: 3,
            initialDelay: 1.0,
            factor: 2.0
        )
    ) {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
```

### Database Operation with Fixed Delay

```swift
func saveToDatabase() async throws {
    try await Retry.attempt(
        configuration: .withFixedDelay(
            maxAttempts: 3,
            delay: 1.0
        )
    ) {
        try await database.save()
    }
}
```

## Contributing

We welcome contributions! Please feel free to submit a Pull Request.

## License

This project is available under the MIT license. See the LICENSE file for more info.
