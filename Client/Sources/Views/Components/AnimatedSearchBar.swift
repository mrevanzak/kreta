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
    
    @Namespace private var animation
    
    var body: some View {
        HStack(spacing: 8) {
            // Departure station badge (always visible after selection)
            if let departure = departureStation {
                stationChip(departure, id: "departure")
                    .transition(.scale.combined(with: .opacity))
            }
            
            // Arrow (visible when departure is selected)
            if departureStation != nil {
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .transition(.scale.combined(with: .opacity))
            }
            
            // Arrival station badge (visible after selection)
            if let arrival = arrivalStation {
                stationChip(arrival, id: "arrival")
                    .transition(.scale.combined(with: .opacity))
            }
            
            // Search field (visible until both stations selected)
            if step == .departure || step == .arrival {
                searchField
                    .matchedGeometryEffect(id: "searchField", in: animation)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
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
    
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            
            TextField(placeholder, text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .frame(maxWidth: .infinity)
    }
    
    private func stationChip(_ station: Station, id: String) -> some View {
        Text(station.code)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .matchedGeometryEffect(id: id, in: animation)
    }
    
    private func dateChip(_ date: Date) -> some View {
        Text(date, format: .dateTime.day().month(.abbreviated))
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    private var placeholder: String {
        switch step {
        case .departure:
            return "Stasiun / Kota"
        case .arrival:
            return "Stasiun Tujuan"
        case .date, .results:
            return ""
        }
    }
}
