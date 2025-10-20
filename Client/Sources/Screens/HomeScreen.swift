import SwiftUI

func getDate(from time: String) -> Date? {
  let formatter = DateFormatter()
  formatter.dateFormat = "yyyy/MM/dd HH:mm"
  return formatter.date(from: time) ?? nil
}

@MainActor
struct HomeScreen: View {
  @available(iOS 16.1, *)
  var trainLiveActivityService: TrainLiveActivityService = TrainLiveActivityService.shared

  var body: some View {
    Button("Train Live Activity") {
      Task { @MainActor in
        do {
          _ = try await trainLiveActivityService.start(
            trainName: "Jayabaya",
            from: TrainStation(
              name: "Malang", code: "ML",
              estimatedArrival: nil,
              estimatedDeparture: getDate(from: "2025/10/17 13:45"),
            ),
            destination: TrainStation(
              name: "Pasar Senen", code: "PSE",
              estimatedArrival: getDate(from: "2025/10/18 01:58"),
              estimatedDeparture: nil
            ),
            nextStation: TrainStation(
              name: "Surabaya Pasarturi", code: "SBI",
              estimatedArrival: getDate(from: "2025/10/17 15:55"),
              estimatedDeparture: getDate(from: "2025/10/18 16:07")
            ),
            seatClass: SeatClass.economy(number: 9),
            seatNumber: "20C",
          )
        } catch {
          print("Failed to start train live activity: \(error)")
        }
      }
    }
  }
}

#Preview {
  HomeScreen()
}
