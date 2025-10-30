//
//  TrainResultRow.swift
//  kreta
//
//  Created by Gilang Banyu Biru Erassunu on 30/10/25.
//

import SwiftUI

struct TrainResultRow: View {
  let train: Train
  
  var body: some View {
    HStack(alignment: .center, spacing: 16) {
      // Train service details
      VStack(alignment: .leading, spacing: 4) {
        Text(train.name)
          .font(.title3).bold()
        
        // Train code
        Text(train.code)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      
      Spacer()
      
      // Chevron indicator
      ZStack {
        Circle()
          .glassEffect()
          .frame(width: 44)
        Image(systemName: "checkmark")
      }
    }
    .padding()
  }
}

#Preview {
  TrainResultRow(
    train: Train(
      id: "1",
      code: "ARGO",
      name: "Argo Bromo Anggrek"
    )
  )
}
