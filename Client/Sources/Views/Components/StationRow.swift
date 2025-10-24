//
//  StationRow.swift
//  tututut
//
//  Created by Gilang Banyu Biru Erassunu on 24/10/25.
//

import SwiftUI

struct StationRow: View {
    let station: Station
    
    var body: some View {
        HStack(spacing: 16) {
            // Station code badge
            ZStack {
                Circle()
                    .fill(.green.opacity(0.2))
                    .frame(width: 56, height: 56)
                
                Text(station.code)
                    .font(.headline)
                    .fontWeight(.bold)
            }
            
            // Station name
            VStack(alignment: .leading, spacing: 4) {
                Text(station.name)
                    .font(.headline)
                
                Text(station.name)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Chevron indicator
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
                .font(.footnote)
        }
        .padding()
        .contentShape(Rectangle())
    }
}
