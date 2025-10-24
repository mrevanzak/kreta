//
//  TrainServiceRow.swift
//  tututut
//
//  Created by Gilang Banyu Biru Erassunu on 24/10/25.
//

import SwiftUI

struct TrainServiceRow: View {
    let train: Route
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Train service details
            VStack(alignment: .leading, spacing: 8) {
                Text(train.name)
                    .font(.headline)
                
                // Route information
                HStack(spacing: 8) {
                    // Departure station
                    HStack(spacing: 4) {
                        Text(train.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text(train.name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Direction arrow
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.green)
                    
                    // Arrival station
                    HStack(spacing: 4) {
                        Text(train.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text(train.name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Chevron indicator
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
                .font(.footnote)
        }
        .padding()
    }
}
