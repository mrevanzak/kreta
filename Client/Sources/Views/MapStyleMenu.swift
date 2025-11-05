//
//  MapStylePicker.swift
//  kreta
//
//  Map overlay style selection component with iOS 26 liquid glass effect
//

import SwiftUI

enum MapStyleOption: String, CaseIterable {
  case standard = "Standard"
  case hybrid = "Hybrid"

  var icon: String {
    switch self {
    case .standard:
      return "map"
    case .hybrid:
      return "globe.asia.australia.fill"
    }
  }

  var displayName: String {
    return rawValue
  }
}

struct MapStylePicker: View {
  @Binding var selectedStyle: MapStyleOption

  var body: some View {
    Menu {
      Picker(selection: $selectedStyle) {
        ForEach(MapStyleOption.allCases, id: \.self) { style in
          Label(style.displayName, systemImage: style.icon)
            .tag(style)
        }
      } label: {
        EmptyView()
      }
      .pickerStyle(.inline)
    } label: {
      Image(systemName: selectedStyle.icon)
        .font(.system(size: 20, weight: .medium))
        .foregroundStyle(.primary)
        .frame(width: 44, height: 44)
        .glassEffect()
    }
    .accessibilityLabel("Select Map Style")
  }
}

#Preview {
  MapStylePicker(selectedStyle: .constant(.hybrid))
    .padding()
}
