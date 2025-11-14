import Foundation

/// Utility for tracking onboarding state
enum OnboardingState {
  private static let hasCompletedOnboardingKey = "hasCompletedPermissionsOnboarding"

  /// Check if user has completed permissions onboarding
  static func hasCompletedOnboarding() -> Bool {
    print(
      "hasCompletedOnboarding: \(UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey))")
    return UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey)
  }

  /// Mark permissions onboarding as complete
  static func markOnboardingComplete() {
    UserDefaults.standard.set(true, forKey: hasCompletedOnboardingKey)
  }

  /// Reset onboarding state (useful for testing)
  static func resetOnboarding() {
    UserDefaults.standard.removeObject(forKey: hasCompletedOnboardingKey)
  }
}
