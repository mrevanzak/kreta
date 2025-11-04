//
//  Constants.swift
//  hello-market-client
//
//  Created by Mohammad Azam on 9/5/24.
//

import Foundation

struct Constants {
  struct Convex {
    // Point this to your Convex deployment; values come from .xcconfig files
    static let deploymentUrl: String = {
      // First try environment variable (for runtime overrides)
      if let url = ProcessInfo.processInfo.environment["CONVEX_URL"], !url.isEmpty {
        return url
      }
      // Then try Info.plist (populated from .xcconfig files at build time)
      if let url = Bundle.main.infoDictionary?["CONVEX_URL"] as? String, !url.isEmpty {
        return url
      }
      #if DEBUG
        print(
          "⚠️ [kreta] CONVEX_URL not set. Configure it in Client/Config/Debug.xcconfig or Release.xcconfig"
        )
      #endif
      return "https://convex.invalid"
    }()
  }

  struct PostHog {
    static let apiKey: String = {
      // First try environment variable (for runtime overrides)
      if let key = ProcessInfo.processInfo.environment["POSTHOG_API_KEY"], !key.isEmpty {
        return key
      }
      // Then try Info.plist (populated from .xcconfig files at build time)
      if let key = Bundle.main.infoDictionary?["POSTHOG_API_KEY"] as? String, !key.isEmpty {
        return key
      }
      #if DEBUG
        print(
          "⚠️ [kreta] POSTHOG_API_KEY not set. Configure it in Client/Config/Debug.xcconfig or Release.xcconfig"
        )
      #endif
      return "invalid-api-key"
    }()
    static let host: String = "https://us.i.posthog.com"
  }

  struct Sentry {
    static let dsn: String? = {
      // First try environment variable (for runtime overrides)
      if let value = ProcessInfo.processInfo.environment["SENTRY_DSN"], !value.isEmpty {
        return value
      }
      // Then try Info.plist (populated from .xcconfig files at build time)
      if let value = Bundle.main.infoDictionary?["SENTRY_DSN"] as? String, !value.isEmpty {
        return value
      }
      #if DEBUG
        print(
          "⚠️ [kreta] SENTRY_DSN not set. Configure it in Client/Config/Debug.xcconfig or Release.xcconfig"
        )
      #endif
      return nil
    }()
  }

  struct AppMeta {
    static let environment: String = {
      if let env = ProcessInfo.processInfo.environment["APS_ENVIRONMENT"], !env.isEmpty {
        return env
      }
      #if DEBUG
        return "development"
      #else
        return "production"
      #endif
    }()

    static let version: String = {
      let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0"
      let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
      return "ios@\(version)(\(build))"
    }()
  }

  struct Urls {

    static let register: URL = URL(string: "http://localhost:8080/api/auth/register")!
    static let login: URL = URL(string: "http://localhost:8080/api/auth/login")!
    static let products: URL = URL(string: "http://localhost:8080/api/products")!
    static let createProduct = URL(string: "http://localhost:8080/api/products")!
    static let uploadProductImage = URL(string: "http://localhost:8080/api/products/upload")!
    static let addCartItem = URL(string: "http://localhost:8080/api/cart/items")!
    static let loadCart = URL(string: "http://localhost:8080/api/cart")!
    static let loadUserInfo = URL(string: "http://localhost:8080/api/user")!
    static let updateUserInfo = URL(string: "http://localhost:8080/api/user")!
    static let createPaymentIntent = URL(
      string: "http://localhost:8080/api/payment/create-payment-intent")!
    static let saveOrder = URL(string: "http://localhost:8080/api/orders")!
    static let loadOrders = URL(string: "http://localhost:8080/api/orders")!
    static let myProducts = URL(string: "http://localhost:8080/api/products/user")!

    static func deleteCartItem(_ cartItemId: Int) -> URL {
      URL(string: "http://localhost:8080/api/cart/item/\(cartItemId)")!
    }

    static func deleteProduct(_ productId: Int) -> URL {
      URL(string: "http://localhost:8080/api/products/\(productId)")!
    }

    static func updateProduct(_ productId: Int) -> URL {
      URL(string: "http://localhost:8080/api/products/\(productId)")!
    }
  }

  struct TrainMap {
    // Base for persepuran server; override via env if needed later
    private static let base: String = "https://persepuran-server.mrevanzak.workers.dev/api/train"
    static let stations: URL = URL(string: "\(base)/stations")!
    static let routes: URL = URL(string: "\(base)/routes")!
    static let positions: URL = URL(string: "\(base)/gapeka")!
  }

}
