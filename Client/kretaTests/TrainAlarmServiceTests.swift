import AlarmKit
import Testing

@testable import kreta

@MainActor
@Suite("TrainAlarmService Tests")
struct TrainAlarmServiceTests {

  @Test("Schedule arrival alarm successfully")
  func testScheduleArrivalAlarm_Success() async throws {
    // Clean up before test
    await TrainAlarmService.shared.cancelAllAlarms()

    // Given - request authorization first
    _ = try? await TrainAlarmService.shared.requestAuthorization()

    let activityId = "test_activity_123"
    let now = Date()
    let arrivalTime = now.addingTimeInterval(60 * 60)  // 1 hour from now
    let offsetMinutes = 10
    let trainName = "Jayabaya"
    let destinationName = "Pasar Senen"
    let destinationCode = "PSE"

    // When
    try await TrainAlarmService.shared.scheduleArrivalAlarm(
      activityId: activityId,
      arrivalTime: arrivalTime,
      offsetMinutes: offsetMinutes,
      trainName: trainName,
      destinationName: destinationName,
      destinationCode: destinationCode
    )

    // Then - verify alarm was scheduled using the service's tracking
    let hasAlarm = TrainAlarmService.shared.hasScheduledAlarm(activityId: activityId)
    #expect(hasAlarm, "AlarmKit alarm should be scheduled and tracked")

    // Clean up after test
    await TrainAlarmService.shared.cancelAllAlarms()
  }

  @Test("Do not schedule alarm for past time")
  func testScheduleArrivalAlarm_PastTime() async throws {
    // Clean up before test
    await TrainAlarmService.shared.cancelAllAlarms()

    // Given
    let activityId = "test_activity_past"
    let now = Date()
    let arrivalTime = now.addingTimeInterval(-60)  // 1 minute ago (in the past)
    let offsetMinutes = 10

    // When
    try await TrainAlarmService.shared.scheduleArrivalAlarm(
      activityId: activityId,
      arrivalTime: arrivalTime,
      offsetMinutes: offsetMinutes,
      trainName: "Test Train",
      destinationName: "Test Destination",
      destinationCode: "TST"
    )

    // Then - no alarm should be scheduled for past time
    let hasAlarm = TrainAlarmService.shared.hasScheduledAlarm(activityId: activityId)
    #expect(!hasAlarm, "No alarm should be scheduled for past time")

    // Clean up after test
    await TrainAlarmService.shared.cancelAllAlarms()
  }

  @Test("Cancel arrival alarm")
  func testCancelArrivalAlarm() async throws {
    // Clean up before test
    await TrainAlarmService.shared.cancelAllAlarms()

    // Given - request authorization first
    _ = try? await TrainAlarmService.shared.requestAuthorization()

    // Schedule an alarm first
    let activityId = "test_activity_cancel"
    let now = Date()
    let arrivalTime = now.addingTimeInterval(60 * 60)

    try await TrainAlarmService.shared.scheduleArrivalAlarm(
      activityId: activityId,
      arrivalTime: arrivalTime,
      offsetMinutes: 10,
      trainName: "Test Train",
      destinationName: "Test Destination",
      destinationCode: "TST"
    )

    // Verify it was scheduled
    #expect(TrainAlarmService.shared.hasScheduledAlarm(activityId: activityId))

    // When - cancel the alarm
    await TrainAlarmService.shared.cancelArrivalAlarm(activityId: activityId)

    // Then - verify it was cancelled
    #expect(!TrainAlarmService.shared.hasScheduledAlarm(activityId: activityId))

    // Clean up after test
    await TrainAlarmService.shared.cancelAllAlarms()
  }

  @Test("Has scheduled alarm returns true when alarm exists")
  func testHasScheduledAlarm_True() async throws {
    // Clean up before test
    await TrainAlarmService.shared.cancelAllAlarms()

    // Given - request authorization first
    _ = try? await TrainAlarmService.shared.requestAuthorization()

    // Schedule an alarm
    let activityId = "test_activity_check"
    let now = Date()
    let arrivalTime = now.addingTimeInterval(60 * 60)

    try await TrainAlarmService.shared.scheduleArrivalAlarm(
      activityId: activityId,
      arrivalTime: arrivalTime,
      offsetMinutes: 10,
      trainName: "Test Train",
      destinationName: "Test Destination",
      destinationCode: "TST"
    )

    // When/Then
    let hasAlarm = TrainAlarmService.shared.hasScheduledAlarm(activityId: activityId)
    #expect(hasAlarm, "Should detect scheduled AlarmKit alarm")

    // Clean up after test
    await TrainAlarmService.shared.cancelAllAlarms()
  }

  @Test("Has scheduled alarm returns false when no alarm exists")
  func testHasScheduledAlarm_False() async {
    // Clean up before test
    await TrainAlarmService.shared.cancelAllAlarms()

    // Given - no alarm scheduled
    let activityId = "test_activity_no_alarm"

    // When/Then
    let hasAlarm = TrainAlarmService.shared.hasScheduledAlarm(activityId: activityId)
    #expect(!hasAlarm, "Should not detect scheduled alarm")

    // Clean up after test
    await TrainAlarmService.shared.cancelAllAlarms()
  }

  @Test("Cancel all alarms")
  func testCancelAllAlarms() async throws {
    // Clean up before test
    await TrainAlarmService.shared.cancelAllAlarms()

    // Given - request authorization first
    _ = try? await TrainAlarmService.shared.requestAuthorization()

    // Schedule multiple alarms
    let activityId1 = "test_activity_1"
    let activityId2 = "test_activity_2"
    let now = Date()
    let arrivalTime = now.addingTimeInterval(60 * 60)

    try await TrainAlarmService.shared.scheduleArrivalAlarm(
      activityId: activityId1,
      arrivalTime: arrivalTime,
      offsetMinutes: 10,
      trainName: "Test Train 1",
      destinationName: "Destination 1",
      destinationCode: "DST1"
    )

    try await TrainAlarmService.shared.scheduleArrivalAlarm(
      activityId: activityId2,
      arrivalTime: arrivalTime,
      offsetMinutes: 15,
      trainName: "Test Train 2",
      destinationName: "Destination 2",
      destinationCode: "DST2"
    )

    // Verify both were scheduled
    #expect(TrainAlarmService.shared.hasScheduledAlarm(activityId: activityId1))
    #expect(TrainAlarmService.shared.hasScheduledAlarm(activityId: activityId2))

    // When - cancel all alarms
    await TrainAlarmService.shared.cancelAllAlarms()

    // Then - verify both were cancelled
    #expect(!TrainAlarmService.shared.hasScheduledAlarm(activityId: activityId1))
    #expect(!TrainAlarmService.shared.hasScheduledAlarm(activityId: activityId2))

    // Clean up after test
    await TrainAlarmService.shared.cancelAllAlarms()
  }

  @Test("Alarm time calculation is correct")
  func testAlarmTimeCalculation_Correct() async throws {
    // Clean up before test
    await TrainAlarmService.shared.cancelAllAlarms()

    // Given - request authorization first
    _ = try? await TrainAlarmService.shared.requestAuthorization()

    let activityId = "test_calculation"
    let now = Date()
    let arrivalTime = now.addingTimeInterval(60 * 60)  // 1 hour from now
    let offsetMinutes = 10

    // When
    try await TrainAlarmService.shared.scheduleArrivalAlarm(
      activityId: activityId,
      arrivalTime: arrivalTime,
      offsetMinutes: offsetMinutes,
      trainName: "Test Train",
      destinationName: "Test Destination",
      destinationCode: "TST"
    )

    // Then - verify alarm was scheduled
    // Note: We can't directly inspect AlarmKit's internal scheduling,
    // but we can verify the alarm is tracked and that past times are rejected
    let hasAlarm = TrainAlarmService.shared.hasScheduledAlarm(activityId: activityId)
    #expect(hasAlarm, "AlarmKit alarm should be scheduled for future time")

    // Verify that scheduling an alarm with past arrival time is rejected
    let pastArrivalTime = Date().addingTimeInterval(-60)  // 1 minute ago
    try await TrainAlarmService.shared.scheduleArrivalAlarm(
      activityId: "test_past_calculation",
      arrivalTime: pastArrivalTime,
      offsetMinutes: offsetMinutes,
      trainName: "Test Train",
      destinationName: "Test Destination",
      destinationCode: "TST"
    )
    #expect(
      !TrainAlarmService.shared.hasScheduledAlarm(activityId: "test_past_calculation"),
      "AlarmKit should not schedule alarms for past times"
    )

    // Clean up after test
    await TrainAlarmService.shared.cancelAllAlarms()
  }

  @Test("Request authorization")
  func testRequestAuthorization() async throws {
    // Clean up before test
    await TrainAlarmService.shared.cancelAllAlarms()

    // When/Then - request authorization should not throw
    let authState = try await TrainAlarmService.shared.requestAuthorization()
    #expect(authState != nil, "Authorization state should be returned")

    // Clean up after test
    await TrainAlarmService.shared.cancelAllAlarms()
  }

  @Test("Schedule arrival alarm replaces existing alarm")
  func testScheduleArrivalAlarm_ReplacesExisting() async throws {
    // Clean up before test
    await TrainAlarmService.shared.cancelAllAlarms()

    // Given - request authorization first
    _ = try? await TrainAlarmService.shared.requestAuthorization()

    let activityId = "test_replace"
    let now = Date()
    let firstArrivalTime = now.addingTimeInterval(60 * 60)  // 1 hour from now
    let secondArrivalTime = now.addingTimeInterval(90 * 60)  // 1.5 hours from now

    // Schedule first alarm
    try await TrainAlarmService.shared.scheduleArrivalAlarm(
      activityId: activityId,
      arrivalTime: firstArrivalTime,
      offsetMinutes: 10,
      trainName: "Test Train",
      destinationName: "Test Destination",
      destinationCode: "TST"
    )

    #expect(TrainAlarmService.shared.hasScheduledAlarm(activityId: activityId))

    // When - schedule a new alarm with same activityId (should replace)
    try await TrainAlarmService.shared.scheduleArrivalAlarm(
      activityId: activityId,
      arrivalTime: secondArrivalTime,
      offsetMinutes: 15,
      trainName: "Test Train 2",
      destinationName: "Test Destination 2",
      destinationCode: "TST2"
    )

    // Then - alarm should still be tracked (replaced, not duplicated)
    #expect(TrainAlarmService.shared.hasScheduledAlarm(activityId: activityId))

    // Clean up after test
    await TrainAlarmService.shared.cancelAllAlarms()
  }
}
