import MapKit
import SwiftUI


@MainActor
struct HomeScreen: View {
  @available(iOS 16.1, *)
  var trainLiveActivityService: TrainLiveActivityService = TrainLiveActivityService.shared
    
    @State private var showTrip = true
    @State private var showAddTrip = false
    
  var body: some View {
    Map{}
    .sheet(isPresented: $showTrip) {
        VStack() {
            HStack {
                Text("Perjalanan Kereta")
                    .font(.title2).bold()
                Spacer()
                Image(systemName: "gear.circle")
                    .font(.system(size: 38))
                    .fontWeight(.bold)
                    .foregroundStyle(Color(.green))
            }
            .padding(.top, 23)
            Button {
                showAddTrip = true
            } label: {
                VStack(spacing: 10) {
                    Image(systemName: "plus")
                        .font(.system(size: 56, weight: .semibold))
                    Text("Tambah Perjalanan\nKereta")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary).bold()
                }
                .frame(maxWidth: .infinity, minHeight: 200)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.secondary)
                )
            }
            .buttonStyle(.plain)
        }
        .presentationDetents([.height(264)])
        .padding(.horizontal, 21)
        .presentationBackground(.white)
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled(true)
    }
    .sheet(isPresented: $showAddTrip) {
        AddTrain { TrainMock in
            
        }
    }
  }
}

#Preview {
  HomeScreen()
}
