import Foundation

struct FeedbackItem: Codable, Identifiable, Sendable {
  let _id: String
  let title: String
  let description: String
  let email: String?
  let status: String
  let createdAt: Int
  let voteCount: Int

  var id: String { _id }

  var statusColor: String {
    switch status.lowercased() {
    case "pending": return "orange"
    case "accepted": return "green"
    case "finished": return "blue"
    default: return "gray"
    }
  }
}

struct CreateFeedbackRequest: Codable, Sendable {
  let title: String
  let description: String
  let email: String?
  let deviceToken: String
}

struct CreateFeedbackResponse: Codable, Sendable {
  let _id: String
}

struct ToggleVoteRequest: Codable, Sendable {
  let feedbackId: String
  let deviceToken: String
}

struct ToggleVoteResponse: Codable, Sendable {
  let voted: Bool
}


