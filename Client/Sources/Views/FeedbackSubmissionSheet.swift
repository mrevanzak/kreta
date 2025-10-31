//
//  FeedbackSubmissionSheet.swift
//  kreta
//
//  Submission form for new feedback items
//

import SwiftUI

struct FeedbackSubmissionSheet: View {
  @Environment(\.dismiss) var dismiss
  @Environment(\.showToast) private var showToast

  let store: FeedbackStore

  @State private var description = ""
  @State private var email = ""
  @State private var isSubmitting = false

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 24) {
        VStack(alignment: .leading, spacing: 8) {
          Text("Describe your feature request")
            .font(.headline.weight(.semibold))
            .foregroundStyle(.primary)

          Text("Tell us what feature you'd like to see in the app. Be as detailed as possible.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        VStack(alignment: .leading, spacing: 12) {
          ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
              .fill(.white)
              .shadow(color: .black.opacity(0.03), radius: 12, x: 0, y: 6)

            RoundedRectangle(cornerRadius: 20, style: .continuous)
              .stroke(Color(.systemGray4), lineWidth: 1)

            TextEditor(text: $description)
              .frame(minHeight: 200)
              .padding(EdgeInsets(top: 18, leading: 16, bottom: 18, trailing: 16))
              .scrollContentBackground(.hidden)
              .foregroundColor(.primary)
              .font(.body)

            if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
              Text("Example: I'd like to see step count comparisons with previous weeks...")
                .foregroundStyle(Color(.systemGray3))
                .font(.body)
                .padding(EdgeInsets(top: 24, leading: 20, bottom: 0, trailing: 20))
            }
          }

          Text("Email (optional)")
            .font(.headline.weight(.semibold))
            .foregroundStyle(.primary)

          TextField("your.email@example.com", text: $email)
            .textFieldStyle(FeedbackTextFieldStyle())
            .keyboardType(.emailAddress)
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)

          Text(
            "Your email won't be visible to other users. We'll only use it to follow up on your request."
          )
          .font(.caption)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        }
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 32)
      .safeAreaInset(edge: .bottom) {
        VStack {
          Button {
            submitFeedback()
          } label: {
            Text(isSubmitting ? "Submitting..." : "Submit Request")
              .font(.headline.weight(.semibold))
              .frame(maxWidth: .infinity)
              .padding(.vertical, 18)
              .foregroundStyle(buttonForegroundColor)
              .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                  .fill(buttonBackgroundColor)
              )
          }
          .disabled(isSubmitDisabled || isSubmitting)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 20)
        .background(
          Color(.systemGray6)
            .ignoresSafeArea(edges: .bottom)
        )
      }
      .navigationTitle("New Feature Request")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
          }
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
    let generatedTitle = deriveTitle(from: trimmedDescription)

    Task {
      do {
        try await store.submitFeedback(
          title: generatedTitle,
          description: trimmedDescription,
          email: emailValue
        )

        DispatchQueue.main.async {
          showToast("Feedback submitted successfully!", type: .success)
          dismiss()
        }
      } catch {
        DispatchQueue.main.async {
          showToast("Failed to submit feedback: \(error.localizedDescription)", type: .error)
          isSubmitting = false
        }
      }
    }
  }

  private func deriveTitle(from description: String) -> String {
    let firstLine = description.components(separatedBy: .newlines).first ?? description
    let trimmed = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
    return String(trimmed.prefix(80))
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
          .fill(.white)
          .shadow(color: .black.opacity(0.03), radius: 12, x: 0, y: 6)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .stroke(Color(.systemGray4), lineWidth: 1)
      )
      .foregroundStyle(.primary)
  }
}

#Preview {
  FeedbackSubmissionSheet(store: FeedbackStore())
}
