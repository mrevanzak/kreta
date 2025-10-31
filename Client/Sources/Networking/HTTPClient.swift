//
//  HTTPClient.swift
//  GroceryApp
//
//  Created by Mohammad Azam on 5/7/23.
//

import Foundation

enum NetworkError: Error {
  case badRequest
  case decodingError(Error)
  case invalidResponse
  case errorResponse(ErrorResponse)
}

extension NetworkError: LocalizedError {

  var errorDescription: String? {
    switch self {
    case .badRequest:
      return NSLocalizedString(
        "Bad Request (400): Unable to perform the request.", comment: "badRequestError")
    case .decodingError(let error):
      return NSLocalizedString("Unable to decode successfully. \(error)", comment: "decodingError")
    case .invalidResponse:
      return NSLocalizedString("Invalid response.", comment: "invalidResponse")
    case .errorResponse(let errorResponse):
      return NSLocalizedString("Error \(errorResponse.message ?? "")", comment: "Error Response")
    }
  }
}

enum HTTPMethod {
  case get([URLQueryItem])
  case post(Data?)
  case delete
  case put(Data?)

  var name: String {
    switch self {
    case .get:
      return "GET"
    case .post:
      return "POST"
    case .delete:
      return "DELETE"
    case .put:
      return "PUT"
    }
  }
}

struct Resource<T: Codable> {
  let url: URL
  var method: HTTPMethod = .get([])
  var headers: [String: String]? = nil
  var modelType: T.Type
}

struct HTTPClient {

  private let session: URLSession

  init() {

    let configuration = URLSessionConfiguration.default
    configuration.httpAdditionalHeaders = ["Content-Type": "application/json"]
    self.session = URLSession(configuration: configuration)
  }

  func load<T: Codable>(_ resource: Resource<T>) async throws -> T {
    let telemetry = Dependencies.shared.telemetry.withContext([
      "service": "api"
    ])
    let span = telemetry.startTransaction(
      name: "HTTP \(resource.method.name) \(resource.url.lastPathComponent)",
      context: [
        "url": resource.url.absoluteString,
        "method": resource.method.name,
      ]
    )

    var headers: [String: String] = [:]

    // Get the token from keychain
    if let token = Keychain<String>.get("jwttoken") {
      headers["Authorization"] = "Bearer \(token)"
    }

    var request = URLRequest(url: resource.url)

    // Add headers to the request
    for (key, value) in headers {
      request.setValue(value, forHTTPHeaderField: key)
    }

    // Set HTTP method and body if needed
    switch resource.method {
    case .get(let queryItems):
      var components = URLComponents(url: resource.url, resolvingAgainstBaseURL: false)
      components?.queryItems = queryItems
      guard let url = components?.url else {
        throw NetworkError.badRequest
      }
      request.url = url

    case .post(let data), .put(let data):
      request.httpMethod = resource.method.name
      request.httpBody = data

    case .delete:
      request.httpMethod = resource.method.name
    }

    // Set custom headers
    if let headers = resource.headers {
      for (key, value) in headers {
        request.setValue(value, forHTTPHeaderField: key)
      }
    }

    #if DEBUG
      debugLogRequest(request)
    #endif

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await session.data(for: request)
    } catch {
      #if DEBUG
        debugLogRequestFailure(request, error: error)
      #endif
      telemetry.capture(
        error: error,
        context: ["endpoint": request.url?.absoluteString ?? "<nil>"],
        level: .error
      )
      span.finish(status: .error("transport"))
      throw error
    }

    guard let httpResponse = response as? HTTPURLResponse else {
      telemetry.capture(message: "Invalid HTTPURLResponse", context: nil, level: .error)
      span.finish(status: .error("invalid_response"))
      throw NetworkError.invalidResponse
    }

    // Check for specific HTTP errors
    switch httpResponse.statusCode {
    case 200...299:
      break  // Success
    default:
      let errorResponse = try JSONDecoder().decode(ErrorResponse.self, from: data)
      telemetry.capture(
        message: "HTTP Error \(httpResponse.statusCode)",
        context: [
          "endpoint": httpResponse.url?.absoluteString ?? "<nil>",
          "status": httpResponse.statusCode,
        ],
        level: .warning
      )
      span.set(tag: "status", value: "\(httpResponse.statusCode)")
      span.finish(status: .error("HTTP \(httpResponse.statusCode)"))
      throw NetworkError.errorResponse(errorResponse)
    }

    // #if DEBUG
    //   debugLogResponse(data: data, response: httpResponse)
    // #endif

    do {

      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601
      let result = try decoder.decode(resource.modelType, from: data)
      span.set(tag: "status", value: "\(httpResponse.statusCode)")
      span.finish(status: .ok)
      return result
    } catch {
      telemetry.capture(
        error: error, context: ["endpoint": httpResponse.url?.absoluteString ?? "<nil>"],
        level: .error)
      span.finish(status: .error("decoding"))
      throw NetworkError.decodingError(error)
    }
  }

  private func createMultipartFormDataBody(data: Data) -> Data? {
    return nil
  }
}

extension HTTPClient {
  static var development: HTTPClient {
    HTTPClient()
  }

}

#if DEBUG
  // MARK: - Debug Logging
  extension HTTPClient {
    fileprivate func debugLogRequest(_ request: URLRequest) {
      let method = request.httpMethod ?? "GET"
      let urlString = request.url?.absoluteString ?? "<no url>"
      var headers = request.allHTTPHeaderFields ?? [:]
      if let auth = headers["Authorization"] {
        headers["Authorization"] = redactAuthorization(auth)
      }

      print("\n➡️ HTTP Request: \(method) \(urlString)")
      if !headers.isEmpty {
        print("Headers:")
        headers.forEach { k, v in print("  \(k): \(v)") }
      }

      if let body = request.httpBody, !body.isEmpty {
        let pretty = prettyPrintedJSONString(from: body) ?? String(data: body, encoding: .utf8)
        print("Body:\n\(pretty ?? "<non-utf8 body, \(body.count) bytes>")")
      }

      if let curl = curlCommand(from: request) {
        print("cURL:\n\(curl)")
      }
    }

    fileprivate func debugLogRequestFailure(_ request: URLRequest, error: Error) {
      let method = request.httpMethod ?? "GET"
      let urlString = request.url?.absoluteString ?? "<no url>"
      print("❌ HTTP Request Failed: \(method) \(urlString)\nError: \(error)")
    }

    fileprivate func debugLogResponse(data: Data, response: HTTPURLResponse) {
      let urlString = response.url?.absoluteString ?? "<no url>"
      print("⬅️ HTTP Response: \(response.statusCode) \(urlString)")
      if !response.allHeaderFields.isEmpty {
        print("Response Headers:")
        response.allHeaderFields.forEach { key, value in
          print("  \(key): \(value)")
        }
      }
      if !data.isEmpty {
        let pretty = prettyPrintedJSONString(from: data) ?? String(data: data, encoding: .utf8)
        if let pretty = pretty {
          // Limit very large bodies
          let maxLen = 16_384
          if pretty.count > maxLen {
            let prefix = pretty.prefix(maxLen)
            print("Response Body (truncated):\n\(prefix)\n… (\(pretty.count - maxLen) more chars)")
          } else {
            print("Response Body:\n\(pretty)")
          }
        } else {
          print("<non-utf8 response body, \(data.count) bytes>")
        }
      }
    }

    fileprivate func prettyPrintedJSONString(from data: Data) -> String? {
      guard let obj = try? JSONSerialization.jsonObject(with: data, options: []),
        JSONSerialization.isValidJSONObject(obj) || obj is [Any] || obj is [String: Any]
      else {
        return nil
      }
      let opts: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys]
      guard let pretty = try? JSONSerialization.data(withJSONObject: obj, options: opts) else {
        return nil
      }
      return String(data: pretty, encoding: .utf8)
    }

    fileprivate func curlCommand(from request: URLRequest) -> String? {
      guard let url = request.url else { return nil }
      var parts: [String] = [
        "curl", "-X", request.httpMethod ?? "GET", "\"\(url.absoluteString)\"",
      ]

      if let headers = request.allHTTPHeaderFields {
        for (k, v) in headers {
          let value = k.lowercased() == "authorization" ? redactAuthorization(v) : v
          parts.append("-H")
          parts.append("\"\(k): \(value)\"")
        }
      }

      if let body = request.httpBody, !body.isEmpty {
        let bodyString = String(data: body, encoding: .utf8) ?? "<binary>"
        // Escape quotes in body
        let escaped = bodyString.replacingOccurrences(of: "\"", with: "\\\"")
        parts.append("--data-raw")
        parts.append("\"\(escaped)\"")
      }

      return parts.joined(separator: " ")
    }

    fileprivate func redactAuthorization(_ value: String) -> String {
      // Try to keep token type, redact token content
      if let space = value.firstIndex(of: " ") {
        let type = value[..<space]
        return "\(type) ******"
      }
      return "******"
    }
  }
#endif
