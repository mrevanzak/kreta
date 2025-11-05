import Foundation
import Testing

@testable import kreta

@Suite("AnalyticsEventService Round Trip Tests")
struct AnalyticsEventServiceTests {

  @Test("Detect round trip within 7 days and reverse direction")
  func testRoundTripDetection_ReverseDirection() async throws {
    let now = Date()
    let previous = AnalyticsEventService.JourneyRecord(
      trainId: "T1",
      fromStationId: "GMR",
      toStationId: "JNG",
      completedAt: Calendar.current.date(byAdding: .day, value: -3, to: now)!
    )

    let current = AnalyticsEventService.JourneyRecord(
      trainId: "T2",
      fromStationId: "JNG",
      toStationId: "GMR",
      completedAt: now
    )

    let result = AnalyticsEventService.shared._test_evaluateRoundTrip(
      currentJourney: current,
      history: [previous]
    )

    #expect(result != nil)
    #expect(result?.isReverseDirection == true)
    #expect((result?.daysBetween ?? 0) >= 2 && (result?.daysBetween ?? 0) <= 3)
  }

  @Test("Do not detect round trip beyond 7 days window")
  func testRoundTripDetection_OutOfWindow() async throws {
    let now = Date()
    let previous = AnalyticsEventService.JourneyRecord(
      trainId: "T1",
      fromStationId: "AAA",
      toStationId: "BBB",
      completedAt: Calendar.current.date(byAdding: .day, value: -10, to: now)!
    )

    let current = AnalyticsEventService.JourneyRecord(
      trainId: "T2",
      fromStationId: "BBB",
      toStationId: "AAA",
      completedAt: now
    )

    let result = AnalyticsEventService.shared._test_evaluateRoundTrip(
      currentJourney: current,
      history: [previous]
    )

    #expect(result == nil)
  }
}
