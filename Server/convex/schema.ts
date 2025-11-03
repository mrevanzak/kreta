import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export default defineSchema({
  devices: defineTable({
    token: v.string(),
    userId: v.union(v.string(), v.null()),
    updatedAt: v.number(),
  })
    .index("by_token", ["token"])
    .index("by_userId", ["userId"]),

  liveActivityUpdates: defineTable({
    deviceToken: v.string(),
    activityId: v.string(),
    token: v.string(),
    updatedAt: v.number(),
  })
    .index("by_activityId", ["activityId"])
    .index("by_deviceToken", ["deviceToken"]),

  liveActivityStartTokens: defineTable({
    deviceToken: v.string(),
    token: v.string(),
    userId: v.union(v.string(), v.null()),
    updatedAt: v.number(),
  })
    .index("by_deviceToken", ["deviceToken"])
    .index("by_token", ["token"])
    .index("by_userId", ["userId"]),

  gapeka: defineTable({
    lastUpdatedAt: v.string(),
  }).index("by_lastUpdatedAt", ["lastUpdatedAt"]),

  stations: defineTable({
    id: v.string(),
    code: v.string(),
    name: v.string(),
    position: v.object({
      latitude: v.number(),
      longitude: v.number(),
    }),
    city: v.string(),
  })
    .index("by_code", ["code"])
    .index("by_customId", ["id"])
    .searchIndex("search_name", {
      searchField: "name",
      filterFields: ["code", "city"],
    }),

  trains: defineTable({
    id: v.string(),
    code: v.string(),
    name: v.string(),
  })
    .index("by_code", ["code"])
    .index("by_customId", ["id"]),

  trainJourneys: defineTable({
    trainId: v.string(),
    trainCode: v.string(),
    trainName: v.string(),

    stationId: v.string(),
    arrivalTime: v.number(),
    departureTime: v.number(),

    routeId: v.union(v.string(), v.null()),
  })
    .index("by_trainId", ["trainId"]) // legacy/simple lookup
    .index("by_stationId", ["stationId"]) // legacy/simple lookup
    .index("by_routeId", ["routeId"]) // legacy/simple lookup
    // New selective composite indexes for bounded range queries
    .index("by_trainId_departure", ["trainId", "departureTime"])
    .index("by_station_departure", ["stationId", "departureTime"])
    .index("by_trainId_station_departure", [
      "trainId",
      "stationId",
      "departureTime",
    ]),

  stationConnections: defineTable({
    stationId: v.string(),
    connectedStationId: v.string(),
    trainIds: v.array(v.string()),
    earliestDeparture: v.number(),
    latestArrival: v.number(),
  })
    .index("by_stationId", ["stationId"])
    .index("by_station_connected", ["stationId", "connectedStationId"]),

  routes: defineTable({
    id: v.string(),
    paths: v.array(
      v.array(
        v.object({
          latitude: v.number(),
          longitude: v.number(),
        })
      )
    ),
  }).index("by_customId", ["id"]),

  feedback: defineTable({
    title: v.string(),
    description: v.string(),
    email: v.union(v.string(), v.null()),
    status: v.union(
      v.literal("pending"),
      v.literal("accepted"),
      v.literal("rejected"),
      v.literal("done")
    ),
    createdAt: v.number(),
  })
    .index("by_createdAt", ["createdAt"])
    .index("by_status", ["status"]),

  votes: defineTable({
    feedbackId: v.id("feedback"),
    deviceToken: v.string(),
    createdAt: v.number(),
  })
    .index("by_feedbackId", ["feedbackId"])
    .index("by_feedback_device", ["feedbackId", "deviceToken"]),

  scheduledLiveActivities: defineTable({
    deviceToken: v.string(),
    startToken: v.string(),
    scheduledStartTime: v.number(),
    trainId: v.string(),
    trainName: v.string(),
    fromStation: v.object({
      name: v.string(),
      code: v.string(),
      estimatedTime: v.union(v.number(), v.null()),
    }),
    destinationStation: v.object({
      name: v.string(),
      code: v.string(),
      estimatedTime: v.union(v.number(), v.null()),
    }),
    status: v.union(
      v.literal("pending"),
      v.literal("started"),
      v.literal("failed"),
      v.literal("cancelled")
    ),
    createdAt: v.number(),
  })
    .index("by_scheduledStartTime", ["scheduledStartTime"])
    .index("by_status", ["status"])
    .index("by_deviceToken", ["deviceToken"]),
});
