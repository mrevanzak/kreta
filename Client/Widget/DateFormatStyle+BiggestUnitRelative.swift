import Foundation
import SwiftUI

// Custom format style for the biggest N units (j = jam, m = menit, d = detik)
struct BiggestUnitRelativeFormatStyle: FormatStyle {
  let units: Int

  init(units: Int = 1) {
    // Clamp to 1...3 supported units
    self.units = max(1, min(units, 3))
  }

  func format(_ value: Date) -> String {
    let now = Date()
    var remainingSeconds = max(0, Int(value.timeIntervalSince(now)))

    let hours = remainingSeconds / 3600
    remainingSeconds %= 3600
    let minutes = remainingSeconds / 60
    remainingSeconds %= 60
    let seconds = remainingSeconds

    var parts: [String] = []
    if hours > 0 && parts.count < units { parts.append("\(hours)j") }
    if minutes > 0 && parts.count < units { parts.append("\(minutes)m") }
    if seconds > 0 && parts.count < units { parts.append("\(seconds)d") }

    if parts.isEmpty {
      // Ensure at least one component is shown
      switch units {
      case 1: return "0d"
      case 2: return "0m 0d"
      default: return "0j 0m 0d"
      }
    }

    return parts.joined(separator: " ")
  }
}

// Extension to add biggestUnitRelative format style
extension FormatStyle where Self == BiggestUnitRelativeFormatStyle {
  static var biggestUnitRelative: BiggestUnitRelativeFormatStyle {
    BiggestUnitRelativeFormatStyle()
  }

  static func biggestUnitRelative(units: Int) -> BiggestUnitRelativeFormatStyle {
    BiggestUnitRelativeFormatStyle(units: units)
  }
}
