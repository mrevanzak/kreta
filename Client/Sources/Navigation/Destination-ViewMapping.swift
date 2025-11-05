import SwiftUI

@ViewBuilder
func view(for destination: FullScreenDestination) -> some View {
  Group {
    switch destination {
    case .arrival(let stationCode, let stationName):
      TrainArriveScreen(stationCode: stationCode, stationName: stationName)
    }
  }
}

@MainActor
@ViewBuilder
func view(for destination: SheetDestination) -> some View {
  Group {
    switch destination {
    case .feedback:
      FeedbackBoardScreen()
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(.ultraThinMaterial)
    case .addTrain:
      AddTrainView()
        .presentationDragIndicator(.visible)
    }
  }
}
