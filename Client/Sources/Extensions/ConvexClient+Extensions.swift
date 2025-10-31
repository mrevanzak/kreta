import Combine
import ConvexMobile
import Foundation

extension ConvexClient {
  /// Bridges a Convex subscription into a plain async function.
  ///
  /// This function subscribes to a Convex query using Combine,
  /// but only returns the first value received and then cancels the subscription,
  /// effectively ignoring any further live updates.
  /// This is useful for situations where you want a one-off response
  /// rather than a stream of updates from the subscription.
  ///
  /// - Parameters:
  ///   - name: The name of the Convex query function to call.
  ///   - args: Optional arguments for the query.
  ///   - output: The expected type of the query result.
  /// - Returns: The decoded result of type `T`.
  /// - Throws: An error if the query fails.
  @MainActor
  public func query<T: Decodable & Sendable>(
    to name: String, with args: [String: ConvexEncodable?]? = nil, yielding output: T.Type? = nil
  ) async throws -> T {
    let telemetry = Dependencies.shared.telemetry
    let span = telemetry.startTransaction(
      name: "convex.query",
      context: [
        "function": name
      ]
    )

    telemetry.addBreadcrumb(
      message: "Convex query start",
      category: "convex",
      data: ["function": name]
    )

    do {
      let value: T = try await withCheckedThrowingContinuation { continuation in
        var didResume = false
        var cancellable: AnyCancellable?

        cancellable = self.subscribe(to: name, with: args, yielding: output)
          .receive(on: DispatchQueue.main)
          .sink(
            receiveCompletion: { completion in
              if case let .failure(error) = completion, !didResume {
                didResume = true
                continuation.resume(throwing: error)
              }
            },
            receiveValue: { value in
              guard !didResume else { return }
              cancellable?.cancel()
              didResume = true
              continuation.resume(returning: value)
            })
      }

      span.finish(status: .ok)
      telemetry.track(
        event: "convex.query",
        properties: [
          "function": name,
          "status": "ok",
        ]
      )
      return value
    } catch {
      span.finish(status: .error(String(describing: error)))
      telemetry.capture(
        error: error,
        context: [
          "function": name,
          "kind": "query",
        ], level: .error)
      telemetry.track(
        event: "convex.query",
        properties: [
          "function": name,
          "status": "error",
        ]
      )
      throw error
    }
  }

  // MARK: - Instrumented helpers for mutation and subscribe

  // Overload keeping the same name with an extra parameter toggle
  @discardableResult
  public func mutation<T: Decodable & Sendable>(
    _ name: String,
    with args: [String: ConvexEncodable?]? = nil,
    captureTelemetry: Bool
  ) async throws -> T {
    if !captureTelemetry {
      return try await self.mutation(name, with: args)
    }
    let telemetry = Dependencies.shared.telemetry
    let span = telemetry.startTransaction(
      name: "convex.mutation",
      context: ["function": name]
    )
    telemetry.addBreadcrumb(
      message: "Convex mutation start",
      category: "convex",
      data: ["function": name]
    )
    do {
      let value: T = try await self.mutation(name, with: args)
      span.finish(status: .ok)
      telemetry.track(
        event: "convex.mutation",
        properties: [
          "function": name,
          "status": "ok",
        ])
      return value
    } catch {
      span.finish(status: .error(String(describing: error)))
      telemetry.capture(
        error: error,
        context: [
          "function": name,
          "kind": "mutation",
        ], level: .error)
      telemetry.track(
        event: "convex.mutation",
        properties: [
          "function": name,
          "status": "error",
        ])
      throw error
    }
  }

  public func subscribe<T: Decodable & Sendable>(
    to name: String,
    with args: [String: ConvexEncodable?]? = nil,
    yielding output: T.Type,
    captureTelemetry: Bool
  ) -> AnyPublisher<T, ClientError> {
    if !captureTelemetry {
      return self.subscribe(to: name, with: args, yielding: output)
    }
    let telemetry = Dependencies.shared.telemetry
    telemetry.addBreadcrumb(
      message: "Convex subscribe",
      category: "convex",
      data: ["function": name]
    )
    return self.subscribe(to: name, with: args, yielding: output)
  }
}
