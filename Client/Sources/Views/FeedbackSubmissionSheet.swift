//
//  FeedbackSubmissionSheet.swift
//  kreta
//
//  Submission form for new feedback items
//

import SwiftUI

struct FeedbackSubmissionSheet: View {
  @Environment(FeedbackStore.self) private var store
  @Environment(\.dismiss) var dismiss
  @Environment(\.showToast) private var showToast
  @Environment(\.colorScheme) private var colorScheme

  @State private var description = ""
  @State private var email = ""
  @State private var isSubmitting = false

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 12) {
        Text(
          "Tulis ide/masukkan kamu disini!"
        )
        .font(.headline.weight(.semibold))
        .foregroundStyle(.primary)

        ZStack(alignment: .topLeading) {
          RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(.systemBackground))
            .shadow(
              color: colorScheme == .dark ? .black.opacity(0.5) : .black.opacity(0.03),
              radius: 12, x: 0, y: 6)

          RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(Color(.separator), lineWidth: 1)

          TextEditor(text: $description)
            .frame(minHeight: 200)
            .padding(EdgeInsets(top: 18, leading: 16, bottom: 18, trailing: 16))
            .scrollContentBackground(.hidden)
            .foregroundColor(.primary)
            .font(.body)

          if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(
              "Contoh: Saya ingin melihat perbandingan jumlah langkah dengan minggu sebelumnya..."
            )
            .foregroundStyle(colorScheme == .dark ? Color(.systemGray2) : Color(.systemGray3))
            .font(.body)
            .padding(EdgeInsets(top: 24, leading: 20, bottom: 0, trailing: 20))
          }
        }

        Text("Email (opsional)")
          .font(.headline.weight(.semibold))
          .foregroundStyle(.primary)

        TextField("email.anda@contoh.com", text: $email)
          .textFieldStyle(FeedbackTextFieldStyle())
          .keyboardType(.emailAddress)
          .textInputAutocapitalization(.never)
          .disableAutocorrection(true)

        Text(
          "Email Anda tidak akan terlihat oleh pengguna lain. Kami hanya akan menggunakannya untuk menindaklanjuti permintaan Anda."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.horizontal, 24)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(role: .close) {
            dismiss()
          } label: {
            Image(systemName: "xmark")
          }
        }

        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button(isSubmitting ? "Mengirim..." : "Kirim Permintaan", action: submitFeedback)
            .disabled(isSubmitDisabled || isSubmitting)
        }
      }
    }
  }

  private var isSubmitDisabled: Bool {
    description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var buttonBackgroundColor: Color {
    isSubmitDisabled || isSubmitting ? Color(.systemGray4) : .accentColor
  }

  private var buttonForegroundColor: Color {
    isSubmitDisabled || isSubmitting ? Color(.systemGray2) : .white
  }

  private func submitFeedback() {
    guard !isSubmitting else { return }

    isSubmitting = true

    let trimmedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
    let emailValue: String? = trimmedEmail.isEmpty ? nil : trimmedEmail

    Task {
      do {
        try await store.submitFeedback(
          // title: generatedTitle,
          description: trimmedDescription,
          email: emailValue
        )

        DispatchQueue.main.async {
          showToast("Umpan balik berhasil dikirim!", type: .success)
          dismiss()
        }
      } catch {
        DispatchQueue.main.async {
          showToast("Gagal mengirim umpan balik: \(error.localizedDescription)", type: .error)
          isSubmitting = false
        }
      }
    }
  }

}

// Custom text field style matching the card-based feedback design
struct FeedbackTextFieldStyle: TextFieldStyle {
  func _body(configuration: TextField<_Label>) -> some View {
    configuration
      .padding(.vertical, 14)
      .padding(.horizontal, 16)
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(Color(.systemBackground))
          .shadow(color: Color(.systemGray).opacity(0.1), radius: 12, x: 0, y: 6)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(Color(.separator), lineWidth: 1)
      )
      .foregroundStyle(.primary)
  }
}

#Preview {
  FeedbackSubmissionSheet()
    .environment(FeedbackStore())
}
