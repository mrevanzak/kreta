import SwiftUI

@MainActor
struct HomeScreen: View {
  #if canImport(ActivityKit)
    @available(iOS 16.1, *)
    var trainLiveActivityService: TrainLiveActivityService = TrainLiveActivityService.shared
  #endif

  var body: some View {
    #if canImport(ActivityKit)
      if #available(iOS 16.1, *) {
        Button("Train Live Activity") {
          Task { @MainActor in
            do {
              _ = try await trainLiveActivityService.start(
                from: "Jakarta", destination: "Bandung", nextStation: "Bandung",
                estimatedArrival: Date()
              )
            } catch {
              print("Failed to start train live activity: \(error)")
            }
          }
        }
      } else {
        Text("Live Activities require iOS 16.1+")
      }
    #else
      Text("Live Activities not supported on this platform")
    #endif
  }
}

#Preview {
  HomeScreen()
}
