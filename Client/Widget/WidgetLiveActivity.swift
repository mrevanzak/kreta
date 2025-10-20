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
            .foregroundColor(.primary)
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
            .foregroundColor(.primary)
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
            .foregroundColor(.primary)
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
            .background(Color.primary)
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
          .foregroundColor(.primary)
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

func getDate(from time: String) -> Date? {
  let formatter = DateFormatter()
  formatter.dateFormat = "yyyy/MM/dd HH:mm"
  return formatter.date(from: time) ?? nil
}

extension TrainActivityAttributes {
  fileprivate static var preview: TrainActivityAttributes {
    TrainActivityAttributes(
      trainName: "Jayabaya",
      from: TrainStation(
        name: "Malang",
        code: "ML",
        estimatedArrival: nil,
        estimatedDeparture: getDate(from: "2025/10/20 13:45"),
      ),
      destination: TrainStation(
        name: "Pasar Senen",
        code: "PSE",
        estimatedArrival: getDate(from: "2025/10/21 01:58"),
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
        estimatedArrival: getDate(from: "2025/10/20 15:39"),
        estimatedDeparture: getDate(from: "2025/10/20 15:43")
      ),
      nextStation: TrainStation(
        name: "Surabaya Pasarturi",
        code: "SBI",
        estimatedArrival: getDate(from: "2025/10/20 15:55"),
        estimatedDeparture: getDate(from: "2025/10/20 16:07")
      ),
    )
  }
}

#Preview("Train Activity", as: .content, using: TrainActivityAttributes.preview) {
  WidgetLiveActivity()
} contentStates: {
  TrainActivityAttributes.ContentState.sample1
}
