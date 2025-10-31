//
//  WidgetLiveActivity.swift
//  Widget
//
//  Created by Revanza Kurniawan on 08/10/25.
//

import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Journey State Specific Views

struct BeforeBoardingView: View {
  let context: ActivityViewContext<TrainActivityAttributes>

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "tram.circle.fill")
        .resizable()
        .scaledToFit()
        .frame(width: 56, height: 56)
        .foregroundColor(.kretaPrimary)

      VStack(alignment: .leading, spacing: 6) {
        Text(context.attributes.trainName)
          .font(.title2)
          .bold()
          .foregroundColor(.kretaPrimary)
          .lineLimit(1)
          .minimumScaleFactor(0.8)

        HStack(alignment: .firstTextBaseline, spacing: 6) {
          HStack(spacing: 4) {
            Image(systemName: "train.side.middle.car")
              .resizable()
              .scaledToFit()
              .frame(width: 12, height: 12)
            Text("\(context.attributes.seatClass.number) \(context.attributes.seatClass.name)")
          }

          HStack(spacing: 4) {
            Image(systemName: "chair.lounge.fill")
              .resizable()
              .scaledToFit()
              .frame(width: 12, height: 12)
            Text(context.attributes.seatNumber)
          }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .font(.caption2)
        .monospacedDigit()
        .foregroundStyle(.secondary)
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 4) {
        Text("Berangkat Dalam")
          .font(.footnote)
          .foregroundStyle(.secondary)

        if let departureTime = context.attributes.from.estimatedDeparture {
          Text(departureTime, format: .biggestUnitRelative(units: 2))
            .font(.body)
            .bold()
            .monospacedDigit()
        }
      }
    }
  }
}

struct OnBoardView: View {
  let context: ActivityViewContext<TrainActivityAttributes>

  var body: some View {
    TrainExpandedBottomView(context: context)
  }
}

struct PrepareToDropOffView: View {
  let context: ActivityViewContext<TrainActivityAttributes>

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading) {
        Label("Segera Turun!", systemImage: "figure.walk.circle.fill")
          .labelReservedIconWidth(24)
          .font(.body)
          .foregroundColor(.kretaPrimary)

        Label {
          Text(context.state.stations.next.name)
        } icon: {
          EmptyView()
        }
        .labelReservedIconWidth(24)
        .font(.body)
        .foregroundColor(.secondary)
      }

      Spacer()

      Image(systemName: "checkmark.circle.fill")
        .resizable()
        .scaledToFit()
        .frame(width: 56, height: 56)
        .foregroundColor(.kretaPrimary)
    }
  }
}

struct ActivityView: View {
  let context: ActivityViewContext<TrainActivityAttributes>

  var body: some View {
    VStack {
      HStack {
        TrainExpandedLeadingView(context: context)
        Spacer()
      }

      switch context.state.journeyState {
      case .beforeBoarding:
        BeforeBoardingView(context: context)
      case .onBoard:
        OnBoardView(context: context)
      case .prepareToDropOff:
        PrepareToDropOffView(context: context)
      }
    }
    .padding()
    // .activityBackgroundTint(Color(uiColor: .systemBackground))
    // .activitySystemActionForegroundColor(Color.accentColor)
  }
}

struct BeforeBoardingSmallView: View {
  let context: ActivityViewContext<TrainActivityAttributes>

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 6) {
        Text(context.attributes.trainName)
          .font(.body)
          .bold()
          .foregroundColor(.kretaPrimary)
          .lineLimit(1)
          .minimumScaleFactor(0.8)

        Text("Berangkat")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 4) {
        Text(
          "\(context.attributes.seatClass.number) \(context.attributes.seatClass.name) | \(context.attributes.seatNumber)"
        )
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .font(.footnote)
        .monospacedDigit()
        .foregroundStyle(.secondary)

        if let departureTime = context.attributes.from.estimatedDeparture {
          Text(departureTime, format: .biggestUnitRelative(units: 2))
            .font(.body)
            .bold()
            .monospacedDigit()
        }
      }
    }
    .padding(.horizontal)
  }
}

struct PrepareToDropOffSmallView: View {
  let context: ActivityViewContext<TrainActivityAttributes>

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading) {
        Text("Segera Turun!")
          .font(.footnote)
          .bold()
          .foregroundColor(.kretaPrimary)
          .lineLimit(1)

        Text(context.state.stations.next.name)
          .font(.caption)
          .bold()
          .foregroundColor(.secondary)
      }

      Spacer(minLength: 2)

      Image(systemName: "figure.walk.circle.fill")
        .resizable()
        .scaledToFit()
        .frame(width: 36, height: 36)
        .foregroundColor(.kretaPrimary)

    }
    .padding(.horizontal)
  }
}

struct ActivitySmallView: View {
  let context: ActivityViewContext<TrainActivityAttributes>

  var body: some View {
    switch context.state.journeyState {
    case .beforeBoarding:
      BeforeBoardingSmallView(context: context)
    case .onBoard:
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
    case .prepareToDropOff:
      PrepareToDropOffSmallView(context: context)
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
        }

        DynamicIslandExpandedRegion(.center) {
        }

        DynamicIslandExpandedRegion(.bottom) {
          switch context.state.journeyState {
          case .beforeBoarding:
            BeforeBoardingView(context: context)
          case .onBoard:
            TrainExpandedBottomView(context: context, withPadding: true)
          case .prepareToDropOff:
            PrepareToDropOffView(context: context)
          }
        }
      } compactLeading: {
        switch context.state.journeyState {
        case .beforeBoarding:
          Image(systemName: "tram.circle.fill")
            .foregroundColor(.kretaPrimary)
        case .onBoard:
          HStack(alignment: .center, spacing: 8) {
            ActivityProgressView(context: context)
            Text(context.attributes.destination.code)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Color.kretaPrimary)
              .clipShape(Capsule())
              .foregroundColor(Color(.systemBackground))
          }
        case .prepareToDropOff:
          Image(systemName: "figure.walk.circle.fill")
            .foregroundColor(.kretaPrimary)
        }

      } compactTrailing: {
        switch context.state.journeyState {
        case .beforeBoarding:
          if let departureTime = context.attributes.from.estimatedDeparture {
            Text(departureTime, format: .biggestUnitRelative(units: 2))
              .foregroundColor(.kretaPrimary)
              .monospacedDigit()
          }
        case .onBoard:
          if let destinationEstimatedArrival = context.attributes.destination
            .estimatedArrival
          {
            Text(
              destinationEstimatedArrival,
              format: .biggestUnitRelative(units: 2)
            )
            .foregroundColor(.kretaPrimary)
          }
        case .prepareToDropOff:
          Text("Turun")
            .foregroundColor(.kretaPrimary)
        }
      } minimal: {
        switch context.state.journeyState {
        case .beforeBoarding:
          Image(systemName: "tram.circle.fill")
            .foregroundColor(.kretaPrimary)
        case .onBoard:
          ActivityProgressView(context: context)
        case .prepareToDropOff:
          Image(systemName: "figure.walk.circle.fill")
            .foregroundColor(.kretaPrimary)
        }
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
  fileprivate static var beforeBoarding: TrainActivityAttributes.ContentState {
    TrainActivityAttributes.ContentState(
      previousStation: TrainStation(
        name: "Malang",
        code: "ML",
        estimatedArrival: nil,
        // set tomorrow at 13:45
        estimatedDeparture: Calendar.current.date(
          bySettingHour: 13, minute: 45, second: 0, of: Date().addingTimeInterval(60 * 60 * 24))
      ),
      nextStation: TrainStation(
        name: "Blitar",
        code: "BL",
        estimatedArrival: nil,
        estimatedDeparture: nil
      ),
      journeyState: .beforeBoarding
    )
  }

  fileprivate static var onBoard: TrainActivityAttributes.ContentState {
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
      journeyState: .onBoard
    )
  }

  fileprivate static var prepareToDropOff: TrainActivityAttributes.ContentState {
    TrainActivityAttributes.ContentState(
      previousStation: TrainStation(
        name: "Gambir",
        code: "GMR",
        estimatedArrival: nil,
        estimatedDeparture: nil
      ),
      nextStation: TrainStation(
        name: "Pasar Senen",
        code: "PSE",
        estimatedArrival: nil,
        estimatedDeparture: nil
      ),
      journeyState: .prepareToDropOff
    )
  }
}

#Preview("Train Activity - Before Boarding", as: .content, using: TrainActivityAttributes.preview) {
  WidgetLiveActivity()
} contentStates: {
  TrainActivityAttributes.ContentState.beforeBoarding
}

#Preview("Train Activity - On Board", as: .content, using: TrainActivityAttributes.preview) {
  WidgetLiveActivity()
} contentStates: {
  TrainActivityAttributes.ContentState.onBoard
}

#Preview(
  "Train Activity - Prepare to Drop Off", as: .content, using: TrainActivityAttributes.preview
) {
  WidgetLiveActivity()
} contentStates: {
  TrainActivityAttributes.ContentState.prepareToDropOff
}
