//
//  WidgetLiveActivity.swift
//  Widget
//
//  Created by Revanza Kurniawan on 08/10/25.
//

import ActivityKit
import SwiftUI
import WidgetKit

struct ActivityView: View {
  let context: ActivityViewContext<TrainActivityAttributes>

  var body: some View {
    VStack {
      HStack {
        TrainExpandedLeadingView(context: context)
        Spacer()
        TrainExpandedTrailingView(context: context)
      }
      TrainExpandedBottomView(context: context)
    }
    .padding()
    // .activityBackgroundTint(Color(uiColor: .systemBackground))
    // .activitySystemActionForegroundColor(Color.accentColor)
  }
}

struct ActivitySmallView: View {
  let context: ActivityViewContext<TrainActivityAttributes>

  var body: some View {
    if let destinationEstimatedArrival = context.attributes.destination.estimatedArrival {
      HStack {
        VStack {
          HStack {
            Text(
              destinationEstimatedArrival,
              format: .biggestUnitRelative(units: 2)
            )
            .font(.body)
            .foregroundColor(.kretaPrimary)
            Spacer()
          }

          ProgressView(
            timerInterval: Date()...destinationEstimatedArrival,
            countsDown: false,
            label: { EmptyView() },
            currentValueLabel: {
            }
          ).progressViewStyle(.linear)

          HStack {
            Text(
              "Tujuan \(context.attributes.destination.name) (\(context.attributes.destination.code))"
            )
            .font(.caption2)
            .foregroundStyle(.foreground)

            Spacer()
          }
        }
      }
      .padding(.all)
    }
  }
}

struct ActivityFamilyView: View {
  let context: ActivityViewContext<TrainActivityAttributes>

  @Environment(\.activityFamily) var activityFamily

  var body: some View {
    switch activityFamily {
    case .small:
      ActivitySmallView(context: context)
    case .medium:
      ActivityView(context: context)
    @unknown default:
      EmptyView()
    }
  }
}

struct ActivityProgressView: View {
  let context: ActivityViewContext<TrainActivityAttributes>

  var body: some View {
    if let destinationEstimatedArrival = context.attributes.destination
      .estimatedArrival
    {
      ProgressView(
        timerInterval: Date()...destinationEstimatedArrival,
        countsDown: false,
        label: { EmptyView() },
        currentValueLabel: {
          Image(systemName: "tram")
            .resizable()
            .scaledToFit()
            .frame(width: 12, height: 12)
            .foregroundColor(.kretaPrimary)
        }
      )
      .progressViewStyle(.circular)
      .frame(width: 24, height: 24)
    }
  }
}

struct TrainExpandedBottomView: View {
  let context: ActivityViewContext<TrainActivityAttributes>
  var withPadding: Bool = false

  var body: some View {
    VStack {
      if let destinationEstimatedArrival = context.attributes.destination.estimatedArrival {
        Spacer()

        VStack(spacing: 0) {
          HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
              Text(context.state.stations.previous.code).font(.body).bold()
              Text(context.state.stations.previous.name)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            }
            .containerRelativeFrame(.horizontal) { size, _ in
              size * 0.25
            }

            VStack {
              Text(context.attributes.trainName)
                .font(.caption)
                .bold()
                .foregroundColor(.gray)

              Image("kereta")
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 15)
                .padding(.bottom, -2)  // visually sit on the progress line
            }

            VStack(alignment: .trailing, spacing: 4) {
              Text(context.state.stations.next.code).font(.body).bold()
              Text(context.state.stations.next.name)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            }
            .containerRelativeFrame(.horizontal) { size, _ in
              size * 0.25
            }
          }

          ProgressView(
            timerInterval: Date()...destinationEstimatedArrival,
            countsDown: false,
            label: { EmptyView() },
            currentValueLabel: { EmptyView() }
          )
          .progressViewStyle(.linear)
        }

        ZStack {
          HStack {
            Text("Estimasi Tiba")
              .font(.caption)
              .if(withPadding) { view in
                view.padding(.leading)
              }
            Spacer()
          }

          HStack(alignment: .center) {
            Text(
              destinationEstimatedArrival,
              format: .biggestUnitRelative(units: 2)
            )
            .font(.callout)
            .bold()
            .foregroundColor(.kretaPrimary)
          }
        }
      }
    }
  }
}

struct TrainExpandedLeadingView: View {
  let context: ActivityViewContext<TrainActivityAttributes>

  var body: some View {
    Text("KRETA").font(.footnote).foregroundColor(.gray)
  }
}

struct TrainExpandedTrailingView: View {
  let context: ActivityViewContext<TrainActivityAttributes>

  var body: some View {
    VStack(alignment: .trailing) {
      HStack(spacing: 4) {
        Text("\(context.attributes.seatClass.number) \(context.attributes.seatClass.name)")
        Image(systemName: "chair.lounge.fill")
          .resizable()
          .scaledToFit()
          .frame(width: 12, height: 12)
      }
      .lineLimit(1)
      .minimumScaleFactor(0.8)

      HStack(spacing: 4) {
        Text(context.attributes.seatNumber)
        Image(systemName: "train.side.middle.car")
          .resizable()
          .scaledToFit()
          .frame(width: 12, height: 12)
      }
      .lineLimit(1)
      .minimumScaleFactor(0.8)
    }
    .font(.caption2)
    .monospacedDigit()
    .foregroundStyle(.gray)
  }
}

struct WidgetLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: TrainActivityAttributes.self) { context in
      ActivityFamilyView(context: context)
    } dynamicIsland: { context in
      DynamicIsland {
        // Expanded regions
        DynamicIslandExpandedRegion(.leading) {
          TrainExpandedLeadingView(context: context)
            .padding(.leading)
        }

        DynamicIslandExpandedRegion(.trailing) {
          TrainExpandedTrailingView(context: context)
            .padding(.trailing)
        }

        DynamicIslandExpandedRegion(.center) {
        }

        DynamicIslandExpandedRegion(.bottom) {
          TrainExpandedBottomView(context: context, withPadding: true)
        }
      } compactLeading: {
        HStack(alignment: .center, spacing: 8) {
          ActivityProgressView(context: context)
          Text(context.attributes.destination.code)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.kretaPrimary)
            .clipShape(Capsule())
            .foregroundColor(Color(.systemBackground))
        }

      } compactTrailing: {
        if let destinationEstimatedArrival = context.attributes.destination
          .estimatedArrival
        {
          Text(
            destinationEstimatedArrival,
            format: .biggestUnitRelative(units: 2)
          )
          .foregroundColor(.kretaPrimary)
        }
      } minimal: {
        ActivityProgressView(context: context)
      }
      .widgetURL(URL(string: "kreta://train"))
      .keylineTint(Color.red)
    }
    .supplementalActivityFamilies([.small, .medium])
  }
}

extension TrainActivityAttributes {
  fileprivate static var preview: TrainActivityAttributes {
    TrainActivityAttributes(
      trainName: "Jayabaya",
      from: TrainStation(
        name: "Malang",
        code: "ML",
        estimatedArrival: nil,
        // set today at 13:45
        estimatedDeparture: Calendar.current.date(
          bySettingHour: 13, minute: 45, second: 0, of: Date())
      ),
      destination: TrainStation(
        name: "Pasar Senen",
        code: "PSE",
        // set tomorrow at 01:58
        estimatedArrival: Calendar.current.date(
          bySettingHour: 1, minute: 58, second: 0, of: Date().addingTimeInterval(60 * 60 * 24)),
        estimatedDeparture: nil
      ),
      seatClass: SeatClass.economy(number: 9),
      seatNumber: "20C"
    )
  }
}

extension TrainActivityAttributes.ContentState {
  fileprivate static var sample1: TrainActivityAttributes.ContentState {
    TrainActivityAttributes.ContentState(
      previousStation: TrainStation(
        name: "Surabayagubeng",
        code: "SGU",
        // set today at 15:39
        estimatedArrival: Calendar.current.date(
          bySettingHour: 15, minute: 39, second: 0, of: Date()),
        // set today at 15:43
        estimatedDeparture: Calendar.current.date(
          bySettingHour: 15, minute: 43, second: 0, of: Date())
      ),
      nextStation: TrainStation(
        name: "Surabaya Pasarturi",
        code: "SBI",
        // set today at 15:55
        estimatedArrival: Calendar.current.date(
          bySettingHour: 15, minute: 55, second: 0, of: Date()),
        // set today at 16:07
        estimatedDeparture: Calendar.current.date(
          bySettingHour: 16, minute: 07, second: 0, of: Date())
      ),
    )
  }
}

#Preview("Train Activity", as: .content, using: TrainActivityAttributes.preview) {
  WidgetLiveActivity()
} contentStates: {
  TrainActivityAttributes.ContentState.sample1
}
