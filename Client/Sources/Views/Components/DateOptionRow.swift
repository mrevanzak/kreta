//
//  DateOptionRow.swift
//  tututut
//
//  Created by Gilang Banyu Biru Erassunu on 24/10/25.
//

import SwiftUI

struct DateOptionRow: View {
  let icon: String
  let title: String
  let subtitle: String
  
  var body: some View {
    HStack(spacing: 12) {
      // Icon badge
      ZStack {
        Circle()
          .foregroundStyle(.backgroundSecondary)
          .glassEffect(.regular.tint(.primary))
          .frame(width: 44)
        
        Image(systemName: icon)
          .font(.title3)
          .foregroundStyle(.textSecondary)
      }
      
      // Title and subtitle
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.headline)
        
        if !subtitle.isEmpty {
          Text(subtitle)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }
      
      Spacer()
    }
    .contentShape(Rectangle())
  }
}

#Preview {
  DateOptionRow(icon: "calendar",
                title: "Hari Ini",
                subtitle: "Pilih berdasarkan hari keberangkatan")
}
