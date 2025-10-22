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
    lastUpdatedAt: v.number(),
  }).index("by_lastUpdatedAt", ["lastUpdatedAt"]),
});
