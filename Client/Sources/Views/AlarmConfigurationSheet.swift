import SwiftUI

// MARK: - Alarm Validation Result

struct AlarmValidationResult {
  let isValid: Bool
  let reason: AlarmValidationFailureReason?

  enum AlarmValidationFailureReason {
    case alarmTimeInPast(minutesUntilDeparture: Int, requestedOffset: Int)
    case journeyTooShort(journeyDuration: Int, requestedOffset: Int, minimumRequired: Int)
  }

  static func valid() -> AlarmValidationResult {
    AlarmValidationResult(isValid: true, reason: nil)
  }

  static func invalid(_ reason: AlarmValidationFailureReason) -> AlarmValidationResult {
    AlarmValidationResult(isValid: false, reason: reason)
  }
}

// MARK: - Alarm Configuration Sheet

struct AlarmConfigurationSheet: View {
  @Environment(\.dismiss) private var dismiss

  @State private var selectedOffset: Int
  @State private var showValidationAlert = false
  @State private var validationResult: AlarmValidationResult?

  let onContinue: (Int) -> Void
  let onValidate: ((Int) -> AlarmValidationResult)?

  // MARK: - Initialization

  init(
    defaultOffset: Int = 10,
    onValidate: ((Int) -> AlarmValidationResult)? = nil,
    onContinue: @escaping (Int) -> Void
  ) {
    self._selectedOffset = State(initialValue: defaultOffset)
    self.onValidate = onValidate
    self.onContinue = onContinue
  }

  // MARK: - Body

  var body: some View {
    NavigationStack {
      VStack(spacing: 24) {
        // Header
        headerView

        // Picker
        pickerView

        Spacer()

        // Continue Button
        continueButton
      }
      .padding()
      .background(Color.backgroundPrimary)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Batal") {
            dismiss()
          }
        }
      }
      .alert("Pengaturan Alarm Tidak Optimal", isPresented: $showValidationAlert) {
        alertButtons
      } message: {
        alertMessage
      }
    }
  }

  // MARK: - Subviews

  private var headerView: some View {
    VStack(spacing: 12) {
      Image(systemName: "bell.badge.fill")
        .font(.system(size: 48))
        .foregroundStyle(.highlight)
        .symbolRenderingMode(.hierarchical)

      Text("Atur Pengingat Kedatangan")
        .font(.title2.weight(.bold))

      Text(
        "Kamu akan menerima alarm sebelum tiba di tujuan. Pilih berapa menit sebelum kedatangan:"
      )
      .font(.body)
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.center)
    }
    .padding(.top)
  }

  private var pickerView: some View {
    VStack(spacing: 8) {
      Text("Waktu Alarm")
        .font(.caption)
        .foregroundStyle(.secondary)

      Picker("Offset Alarm", selection: $selectedOffset) {
        ForEach(1...60, id: \.self) { minutes in
          Text("\(minutes) menit")
            .tag(minutes)
        }
      }
      .pickerStyle(.wheel)
      .frame(height: 150)
      .clipped()
    }
  }

  private var continueButton: some View {
    Button {
      handleContinue()
    } label: {
      Text("Lanjutkan")
        .font(.headline)
        .foregroundStyle(.lessDark)
        .frame(maxWidth: .infinity)
        .padding()
        .background(.highlight)
        .cornerRadius(1000)
    }
  }

  // MARK: - Alert Components

  @ViewBuilder
  private var alertButtons: some View {
    Button("Ubah Pengaturan", role: .cancel) {
      showValidationAlert = false
    }

    Button("Lanjutkan") {
      showValidationAlert = false
      proceedWithConfiguration()
    }
  }

  @ViewBuilder
  private var alertMessage: some View {
    if let reason = validationResult?.reason {
      switch reason {
      case .alarmTimeInPast(let minutesUntilDeparture, let requestedOffset):
        Text(
          "Kereta berangkat dalam \(minutesUntilDeparture) menit, alarm \(requestedOffset) menit tidak akan berbunyi. Ubah pengaturan alarm atau lanjutkan tanpa alarm?"
        )

      case .journeyTooShort(let journeyDuration, let requestedOffset, let minimumRequired):
        Text(
          "Perjalanan hanya \(journeyDuration) menit, alarm \(requestedOffset) menit memerlukan perjalanan minimal \(minimumRequired) menit. Ubah pengaturan atau lanjutkan?"
        )
      }
    }
  }

  // MARK: - Actions

  private func handleContinue() {
    // Validate if validator provided
    if let validate = onValidate {
      let result = validate(selectedOffset)
      validationResult = result

      if !result.isValid {
        showValidationAlert = true
        return
      }
    }

    proceedWithConfiguration()
  }

  private func proceedWithConfiguration() {
    onContinue(selectedOffset)
    dismiss()
  }
}

// MARK: - Preview

#Preview("Configuration Sheet") {
  AlarmConfigurationSheet(
    defaultOffset: 10,
    onValidate: { offset in
      // Mock validation
      if offset > 30 {
        return .invalid(
          .journeyTooShort(journeyDuration: 25, requestedOffset: offset, minimumRequired: 40))
      }
      return .valid()
    },
    onContinue: { offset in
      print("Selected offset: \(offset)")
    }
  )
}
