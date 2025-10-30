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
    try await withCheckedThrowingContinuation { continuation in
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
  }
}
