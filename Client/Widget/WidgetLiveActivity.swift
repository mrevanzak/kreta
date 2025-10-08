//
//  WidgetLiveActivity.swift
//  Widget
//
//  Created by Revanza Kurniawan on 08/10/25.
//

import ActivityKit
import SwiftUI
import UIKit
import WidgetKit

@available(iOSApplicationExtension 16.1, *)
struct WidgetLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: TrainActivityAttributes.self) { context in
      // Lock screen / banner UI
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 8) {
          Text("🚆")
          Text("\(context.attributes.from) → \(context.attributes.destination)")
            .font(.headline)
        }
        Text("Next: \(context.state.nextStation)")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        HStack(spacing: 6) {
          Image(systemName: "clock")
          // Relative time remaining until the destination ETA
          Text(context.state.estimatedArrival, style: .relative)
            .font(.title3).monospacedDigit()
        }
      }
      .padding(.vertical, 8)
      .activityBackgroundTint(Color(uiColor: .systemBackground))
      .activitySystemActionForegroundColor(Color.accentColor)

    } dynamicIsland: { context in
      DynamicIsland {
        // Expanded regions
        DynamicIslandExpandedRegion(.leading) {
          Text("🚆")
        }

        DynamicIslandExpandedRegion(.trailing) {
          Text(context.state.estimatedArrival, style: .relative)
            .monospacedDigit()
        }
        DynamicIslandExpandedRegion(.center) {
          VStack(spacing: 2) {
            Text("\(context.attributes.from) → \(context.attributes.destination)")
              .font(.subheadline).bold()
            Text("Next: \(context.state.nextStation)")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        DynamicIslandExpandedRegion(.bottom) {
          EmptyView()
        }
      } compactLeading: {
        Text("🚆")
      } compactTrailing: {
        Text(context.state.estimatedArrival, style: .relative)
          .monospacedDigit()
      } minimal: {
        Text("🚆")
      }
      .widgetURL(URL(string: "tututut://train"))
      .keylineTint(Color.red)
    }
  }
}

@available(iOSApplicationExtension 16.1, *)
extension TrainActivityAttributes {
  fileprivate static var preview: TrainActivityAttributes {
    TrainActivityAttributes(from: "Jakarta", destination: "Bandung")
  }
}

@available(iOSApplicationExtension 16.1, *)
extension TrainActivityAttributes.ContentState {
  fileprivate static var sample1: TrainActivityAttributes.ContentState {
    TrainActivityAttributes.ContentState(
      nextStation: "Bekasi",
      estimatedArrival: Date().addingTimeInterval(60 * 45)
    )
  }

  fileprivate static var sample2: TrainActivityAttributes.ContentState {
    TrainActivityAttributes.ContentState(
      nextStation: "Purwakarta",
      estimatedArrival: Date().addingTimeInterval(60 * 15)
    )
  }
}

@available(iOSApplicationExtension 16.1, *)
#Preview("Train Activity", as: .content, using: TrainActivityAttributes.preview) {
  WidgetLiveActivity()
} contentStates: {
  TrainActivityAttributes.ContentState.sample1
  TrainActivityAttributes.ContentState.sample2
}
