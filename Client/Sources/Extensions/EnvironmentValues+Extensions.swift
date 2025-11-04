import ConvexMobile
import Foundation
import OSLog
import SwiftUI

extension EnvironmentValues {
  @Entry var httpClient = HTTPClient()
}

extension EnvironmentValues {
  @Entry var convexClient = Dependencies.shared.convexClient
}
