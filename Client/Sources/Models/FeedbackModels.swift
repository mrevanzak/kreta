//
//  FeedbackModels.swift
//  kreta
//
//  Models for feedback board feature
//

import Foundation

struct FeedbackItem: Codable, Identifiable {
  let _id: String
  let title: String
  let description: String
  let email: String?
  let status: String  // "pending", "accepted", "finished"
  let createdAt: Int
  let voteCount: Int

  var id: String { _id }

  var statusColor: String {
    switch status {
    case "pending":
      return "#FF9500"  // orange
    case "accepted":
      return "#34C759"  // green
    case "finished":
      return "#007AFF"  // blue
    default:
      return "#808080"  // gray
    }
  }

  var relativeTime: String {
    let now = Date().timeIntervalSince1970
    let secondsAgo = now - Double(createdAt) / 1000.0

    if secondsAgo < 60 {
      return "\(Int(secondsAgo))s ago"
    } else if secondsAgo < 3600 {
      let minutes = Int(secondsAgo / 60)
      return "\(minutes)m ago"
    } else if secondsAgo < 86400 {
      let hours = Int(secondsAgo / 3600)
      return "\(hours)h ago"
    } else {
      let days = Int(secondsAgo / 86400)
      return "\(days)d ago"
    }
  }
}

struct ToggleVoteResponse: Codable {
  let voted: Bool
}

struct CreateFeedbackResponse: Codable {
  let _id: String

  enum CodingKeys: String, CodingKey {
    case _id
  }
}

// Sort options for feedback board
enum SortOption: String, CaseIterable {
  case votes = "votes"
  case date = "date"

  var displayName: String {
    switch self {
    case .votes:
      return "Votes"
    case .date:
      return "Date"
    }
  }
}

enum SortOrder: String, CaseIterable {
  case ascending = "asc"
  case descending = "desc"

  var displayName: String {
    switch self {
    case .ascending:
      return "Ascending"
    case .descending:
      return "Descending"
    }
  }

  var icon: String {
    switch self {
    case .ascending:
      return "arrow.up"
    case .descending:
      return "arrow.down"
    }
  }
}

