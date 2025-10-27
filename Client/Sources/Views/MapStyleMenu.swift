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
      return "globe"
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
      ForEach(MapStyleOption.allCases, id: \.self) { style in
        Button {
          selectedStyle = style
        } label: {
          Label(style.displayName, systemImage: style.icon)
        }
      }
    } label: {
      Image(systemName: selectedStyle.icon)
        .font(.system(size: 20, weight: .medium))
        .foregroundStyle(.primary)
        .frame(width: 44, height: 44)
        .background(.regularMaterial, in: Circle())
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    .accessibilityLabel("Select Map Style")
  }
}

#Preview {
  MapStylePicker(selectedStyle: .constant(.hybrid))
    .padding()
}
