import Foundation
import Testing

@testable import kreta

@Suite("TrainLiveActivityService Concurrency Tests")
struct TrainLiveActivityServiceConcurrencyTests {

  @Test("LiveActivityRegistry prevents double start")
  func testRegistryDoesNotAllowDoubleStart() async {
    let registry = LiveActivityRegistry()

    let firstStart = await registry.startMonitoringIfNeeded()
    let secondStart = await registry.startMonitoringIfNeeded()

    #expect(firstStart)
    #expect(secondStart == false)
  }

  @Test("LiveActivityRegistry stores and removes timers")
  func testRegistryStoresAndRemovesTimers() async {
    let registry = LiveActivityRegistry()

    let activityId = "activity.timer.test"
    let timer = Task { await Task.yield() }
    let existing = await registry.storeTimer(timer, for: activityId)
    #expect(existing == nil)

    let removed = await registry.removeTimer(for: activityId)
    #expect(removed != nil)
    removed?.cancel()

    let removedAgain = await registry.removeTimer(for: activityId)
    #expect(removedAgain == nil)

    let otherTimer = Task { await Task.yield() }
    _ = await registry.storeTimer(otherTimer, for: "activity.timer.test.2")
    let drained = await registry.drainTimers()
    #expect(drained.isEmpty == false)
    drained.forEach { $0.cancel() }

    let noTimerAfterDrain = await registry.removeTimer(for: "activity.timer.test.2")
    #expect(noTimerAfterDrain == nil)
  }

  @Test("calculateRetryDelay applies jitter bounds")
  func testCalculateRetryDelayWithinBounds() {
    let attempt = 1
    let delay = TrainLiveActivityService.shared.calculateRetryDelay(for: attempt)

    let baseDelay = UInt64(
      pow(2.0, Double(attempt)) * TrainLiveActivityService.Constants.baseRetryDelay
        * Double(TrainLiveActivityService.Constants.nanosecondsPerSecond)
    )
    let maximumDelay = baseDelay + TrainLiveActivityService.Constants.retryJitterNanoseconds

    #expect(delay >= baseDelay)
    #expect(delay <= maximumDelay)
  }

  @Test("shouldScheduleAlarm coalesces duplicates and honours force flag")
  func testShouldScheduleAlarmCoalescing() async {
    let registry = LiveActivityRegistry()
    let activityId = "activity.alarm.test"
    let arrival = Date()
    let offsetMinutes = 5

    let first = await registry.shouldScheduleAlarm(
      activityId: activityId,
      arrivalTime: arrival,
      offsetMinutes: offsetMinutes,
      alarmEnabled: true
    )
    let duplicate = await registry.shouldScheduleAlarm(
      activityId: activityId,
      arrivalTime: arrival,
      offsetMinutes: offsetMinutes,
      alarmEnabled: true
    )
    let forced = await registry.shouldScheduleAlarm(
      activityId: activityId,
      arrivalTime: arrival,
      offsetMinutes: offsetMinutes,
      alarmEnabled: true,
      force: true
    )
    let updatedArrival = await registry.shouldScheduleAlarm(
      activityId: activityId,
      arrivalTime: arrival.addingTimeInterval(120),
      offsetMinutes: offsetMinutes,
      alarmEnabled: true
    )

    #expect(first)
    #expect(duplicate == false)
    #expect(forced)
    #expect(updatedArrival)
  }
}
