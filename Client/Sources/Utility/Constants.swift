//
//  Constants.swift
//  hello-market-client
//
//  Created by Mohammad Azam on 9/5/24.
//

import Foundation

struct Constants {
  struct Convex {
    // Point this to your Convex deployment; consider swapping via build configs
    static let deploymentUrl: String = {
      if let url = ProcessInfo.processInfo.environment["CONVEX_URL"], !url.isEmpty {
        return url
      }
      #if DEBUG
        print(
          "⚠️ [kreta] CONVEX_URL not set. Configure it in the Xcode scheme or shell environment.")
      #endif
      return "https://convex.invalid"
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
