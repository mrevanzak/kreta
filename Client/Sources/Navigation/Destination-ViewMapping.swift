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
    case .addTrain:
      AddTrainView()
        .presentationDragIndicator(.visible)
    case .shareJourney:
      ShareScreen()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    case .alarmConfiguration:
      AlarmConfigurationSheetContainer()
    }
  }
}

// MARK: - Alarm Configuration Wrapper

private struct AlarmConfigurationSheetContainer: View {
  @Environment(TrainMapStore.self) private var store
  @State private var latestValidationResult: AlarmValidationResult = .valid()

  var body: some View {
    if let journeyData = store.selectedJourneyData, store.selectedTrain != nil {
      AlarmConfigurationSheet(
        defaultOffset: AlarmPreferences.shared.defaultAlarmOffsetMinutes,
        onValidate: { offset in
          let result = store.validateAlarmTiming(
            offsetMinutes: offset,
            departureTime: journeyData.userSelectedDepartureTime,
            arrivalTime: journeyData.userSelectedArrivalTime
          )
          latestValidationResult = result
          return result
        },
        onContinue: { offset in
          let validationSnapshot = latestValidationResult
          Task {
            await store.applyAlarmConfiguration(
              offsetMinutes: offset,
              validationResult: validationSnapshot
            )
          }
        }
      )
    } else {
      ContentUnavailableView(
        "Perjalanan Tidak Aktif",
        systemImage: "train.side.front.car",
        description: Text("Silakan pilih perjalanan kereta untuk mengatur alarm.")
      )
    }
  }
}
