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

  @State private var title = ""
  @State private var description = ""
  @State private var email = ""
  @State private var isSubmitting = false

  var body: some View {
    NavigationStack {
      ZStack {
        Color.black.ignoresSafeArea()

        ScrollView {
          VStack(spacing: 32) {
            // Header
            VStack(spacing: 12) {
              Image(systemName: "lightbulb")
                .font(.system(size: 48))
                .foregroundStyle(.cyan)

              Text("New Feature Request")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            }
            .padding(.top, 40)

            // Form fields
            VStack(alignment: .leading, spacing: 24) {
              // Title
              VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                  .font(.subheadline)
                  .fontWeight(.semibold)
                  .foregroundStyle(.secondary)

                TextField("Brief summary of your idea", text: $title)
                  .textFieldStyle(FeedbackTextFieldStyle())
              }

              // Description
              VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                  .font(.subheadline)
                  .fontWeight(.semibold)
                  .foregroundStyle(.secondary)

                TextEditor(text: $description)
                  .frame(minHeight: 120)
                  .padding(12)
                  .background(Color(white: 0.15))
                  .clipShape(RoundedRectangle(cornerRadius: 12))
                  .overlay(
                    RoundedRectangle(cornerRadius: 12)
                      .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                  )
                  .overlay(
                    Group {
                      if description.isEmpty {
                        VStack {
                          HStack {
                            Text("Example: I'd like to see...")
                              .foregroundStyle(.secondary)
                              .padding(.leading, 16)
                              .padding(.top, 20)
                            Spacer()
                          }
                          Spacer()
                        }
                      }
                    },
                    alignment: .topLeading
                  )
                  .foregroundStyle(.white)
              }

              // Email (optional)
              VStack(alignment: .leading, spacing: 8) {
                Text("Email (Optional)")
                  .font(.subheadline)
                  .fontWeight(.semibold)
                  .foregroundStyle(.secondary)

                TextField("your@email.com", text: $email)
                  .textFieldStyle(FeedbackTextFieldStyle())
                  .keyboardType(.emailAddress)
                  .autocapitalization(.none)

                Text("We'll use this to keep you updated on your request")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
            .padding(.horizontal, 21)
            .padding(.bottom, 100)  // Space for submit button
          }
        }

        // Submit button pinned to bottom
        VStack {
          Spacer()

          Button {
            submitFeedback()
          } label: {
            Text("Submit Feedback")
              .font(.headline)
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .frame(height: 56)
              .background(
                isSubmitDisabled ? Color(white: 0.3) : .blue,
                in: RoundedRectangle(cornerRadius: 16)
              )
          }
          .disabled(isSubmitDisabled || isSubmitting)
          .padding(.horizontal, 21)
          .padding(.bottom, 32)
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .foregroundStyle(.white)
          }
        }
      }
    }
  }

  private var isSubmitDisabled: Bool {
    title.trimmingCharacters(in: .whitespaces).isEmpty
      || description.trimmingCharacters(in: .whitespaces).isEmpty
  }

  private func submitFeedback() {
    guard !isSubmitting else { return }

    isSubmitting = true

    let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
    let trimmedDescription = description.trimmingCharacters(in: .whitespaces)
    let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
    let emailValue: String? = trimmedEmail.isEmpty ? nil : trimmedEmail

    Task {
      do {
        try await store.submitFeedback(
          title: trimmedTitle,
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
}

// Custom text field style matching the liquid glass theme
struct FeedbackTextFieldStyle: TextFieldStyle {
  func _body(configuration: TextField<_Label>) -> some View {
    configuration
      .padding(12)
      .background(Color(white: 0.15))
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .strokeBorder(.white.opacity(0.1), lineWidth: 1)
      )
      .foregroundStyle(.white)
  }
}

#Preview {
  FeedbackSubmissionSheet(store: FeedbackStore())
}

