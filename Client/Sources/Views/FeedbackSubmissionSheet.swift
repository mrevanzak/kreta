import SwiftUI

struct FeedbackSubmissionSheet: View {
  @Environment(\.dismiss) var dismiss
  @Environment(\.showMessage) var showMessage

  @Bindable var store: FeedbackStore

  @State private var title: String = ""
  @State private var description: String = ""
  @State private var email: String = ""
  @State private var isSubmitting: Bool = false

  var body: some View {
    NavigationStack {
      ZStack(alignment: .bottom) {
        Color.black.ignoresSafeArea()

        ScrollView {
          VStack(spacing: 24) {
            header

            VStack(spacing: 12) {
              TextField("Title", text: $title)
                .textInputAutocapitalization(.sentences)
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.2, green: 0.2, blue: 0.2)))
                .foregroundStyle(.white)

              ZStack(alignment: .topLeading) {
                TextEditor(text: $description)
                  .frame(minHeight: 140)
                  .padding(8)
                  .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                  .background(RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.2, green: 0.2, blue: 0.2)))
                  .foregroundStyle(.white)

                if description.isEmpty {
                  Text("Example: I'd like to see...")
                    .foregroundStyle(.secondary)
                    .padding(.top, 14)
                    .padding(.leading, 14)
                }
              }

              VStack(alignment: .leading, spacing: 8) {
                TextField("Email (optional)", text: $email)
                  .textContentType(.emailAddress)
                  .keyboardType(.emailAddress)
                  .autocapitalization(.none)
                  .padding()
                  .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                  .background(RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.2, green: 0.2, blue: 0.2)))
                  .foregroundStyle(.white)

                Text("We'll only use this to contact you about your request.")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
            .padding(.horizontal)

            Spacer(minLength: 80)
          }
          .padding(.top)
        }

        Button(action: submit) {
          HStack {
            if isSubmitting { ProgressView().tint(.white) }
            Text("Submit")
              .bold()
          }
          .frame(maxWidth: .infinity)
          .padding()
          .background(RoundedRectangle(cornerRadius: 14).fill(title.isEmpty || description.isEmpty ? Color.gray.opacity(0.4) : Color.blue))
          .foregroundStyle(.white)
          .padding()
        }
        .disabled(title.isEmpty || description.isEmpty || isSubmitting)
      }
    }
  }

  private var header: some View {
    HStack {
      Button(action: { dismiss() }) {
        Image(systemName: "xmark")
          .foregroundStyle(.white)
          .padding(10)
          .background(Circle().fill(.thinMaterial))
      }
      Spacer()
      Text("New Feature Request")
        .font(.headline)
        .foregroundStyle(.white)
      Spacer()
      Color.clear.frame(width: 38, height: 38)
    }
    .padding(.horizontal)
  }

  private func submit() {
    Task {
      isSubmitting = true
      defer { isSubmitting = false }
      do {
        try await store.submitFeedback(title: title, description: description, email: email)
        showMessage("Feedback submitted!", .success)
        dismiss()
      } catch {
        showMessage(error.localizedDescription, .error)
      }
    }
  }
}


