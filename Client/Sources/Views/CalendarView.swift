//
//  CalendarView.swift
//  kreta
//
//  Created by Gilang Banyu Biru Erassunu on 27/10/25.
//

import SwiftUI
import MijickCalendarView

struct CalendarView: View {
  @Binding var selectedDate: Date?
  let onDateSelected: (Date) -> Void
  
  @State private var selectedRange: MDateRange? = .init()
  
  var body: some View {
    MCalendarView(selectedDate: $selectedDate, selectedRange: $selectedRange)
      .onChange(of: selectedDate) { _, newValue in
        if let date = newValue {
          onDateSelected(date)
        }
      }
  }
}

#Preview {
  @Previewable @State var selectedDate: Date? = nil
  
  CalendarView(selectedDate: $selectedDate, onDateSelected: { _ in })
}
