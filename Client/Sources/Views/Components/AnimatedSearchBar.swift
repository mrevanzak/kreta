//
//  AnimatedSearchBar.swift
//  tututut
//
//  Created by Gilang Banyu Biru Erassunu on 24/10/25.
//

import SwiftUI

struct AnimatedSearchBar: View {
  let step: SelectionStep
  let departureStation: Station?
  let arrivalStation: Station?
  let selectedDate: Date?
  @Binding var searchText: String
  let onDepartureChipTap: () -> Void
  let onArrivalChipTap: () -> Void
  let onDateTextSubmit: (() -> Void)?
  
  @Namespace private var animation
  @State private var clearingDeparture = false
  @State private var clearingArrival = false
  
  var body: some View {
    HStack(spacing: 8) {
      // Departure station chip (visible from arrival step onwards, unless clearing)
      if let departure = departureStation, step != .departure && !clearingDeparture {
        Button {
          clearingDeparture = true
          Task {
            try? await Task.sleep(for: .milliseconds(50))
            onDepartureChipTap()
            try? await Task.sleep(for: .milliseconds(50))
            clearingDeparture = false
          }
        } label: {
          stationChip(departure, id: "departure", isClearing: clearingDeparture)
        }
        .buttonStyle(ChipButtonStyle())
        .transition(.asymmetric(
          insertion: .move(edge: .leading).combined(with: .opacity),
          removal: .scale.combined(with: .opacity)
        ))
        .sensoryFeedback(.selection, trigger: clearingDeparture)
      }
      
      // Arrow (visible when departure is selected and not in departure step)
      if departureStation != nil && step != .departure {
        Image(systemName: "arrow.right")
          .font(.caption)
          .foregroundStyle(.tertiary)
          .transition(.scale.combined(with: .opacity))
      }
      
      // Arrival station chip (visible from date step onwards, unless clearing)
      if let arrival = arrivalStation, (step == .date || step == .results) && !clearingArrival {
        Button {
          clearingArrival = true
          Task {
            try? await Task.sleep(for: .milliseconds(50))
            onArrivalChipTap()
            try? await Task.sleep(for: .milliseconds(50))
            clearingArrival = false
          }
        } label: {
          stationChip(arrival, id: "arrival", isClearing: clearingArrival)
        }
        .buttonStyle(ChipButtonStyle())
        .transition(.asymmetric(
          insertion: .move(edge: .leading).combined(with: .opacity),
          removal: .scale.combined(with: .opacity)
        ))
        .sensoryFeedback(.selection, trigger: clearingArrival)
      }
      
      // Text field for station selection (departure or arrival)
      if step == .departure || step == .arrival {
        searchTextField
          .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
          ))
      }
      
      // Date text field
      if step == .date {
        dateTextField
          .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
          ))
      }
      
      // Date display (visible in results step)
      if step == .results, let date = selectedDate {
        Spacer()
        dateChip(date)
          .transition(.scale.combined(with: .opacity))
      }
    }
    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: step)
    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: departureStation?.id)
    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: arrivalStation?.id)
  }
  
  private var searchTextField: some View {
    HStack(spacing: 8) {
      Image(systemName: "magnifyingglass")
        .font(.subheadline)
        .foregroundStyle(.tertiary)
      
      TextField("Stasiun / Kota", text: $searchText)
        .textFieldStyle(.plain)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .frame(maxWidth: .infinity)
  }
  
  private var dateTextField: some View {
    HStack(spacing: 8) {
      Image(systemName: "calendar")
        .font(.subheadline)
        .foregroundStyle(.tertiary)
      
      TextField("Hari, Tanggal", text: $searchText)
        .textFieldStyle(.plain)
        .keyboardType(.numbersAndPunctuation)
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .submitLabel(.done)
        .onSubmit {
          onDateTextSubmit?()
        }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .frame(maxWidth: .infinity)
  }
  
  private func stationChip(_ station: Station, id: String, isClearing: Bool) -> some View {
    HStack(spacing: 6) {
      Text(station.code)
        .font(.subheadline.weight(.semibold))
        .opacity(isClearing ? 0 : 1)
        .scaleEffect(isClearing ? 0.5 : 1)
      
      Image(systemName: "xmark.circle.fill")
        .font(.caption)
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(.secondary)
        .opacity(isClearing ? 0 : 1)
        .scaleEffect(isClearing ? 0.5 : 1)
    }
    .foregroundStyle(.primary)
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .frame(minWidth: 60)
    .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .matchedGeometryEffect(id: id, in: animation)
    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    .hoverEffect(.highlight)
    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isClearing)
  }
  
  private func dateChip(_ date: Date) -> some View {
    Text(date, format: .dateTime.day().month())
      .font(.subheadline.weight(.medium))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
  }
}

// MARK: - Button Style

/// Custom button style for station chips with press animation and feedback.
struct ChipButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
      .opacity(configuration.isPressed ? 0.8 : 1.0)
      .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
  }
}
