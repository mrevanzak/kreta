import { mutation } from "./_generated/server";
import { v } from "convex/values";

// Store/update a device token associated with a user (optional)
export const registerDevice = mutation({
  args: {
    token: v.string(),
    userId: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("devices")
      .filter((q) => q.eq(q.field("token"), args.token))
      .first();

    const doc = {
      token: args.token,
      userId: args.userId ?? null,
      updatedAt: Date.now(),
    } as const;

    if (existing) {
      await ctx.db.patch(existing._id, doc);
      return { success: true, updated: true } as const;
    }
    await ctx.db.insert("devices", doc);
    return { success: true, created: true } as const;
  },
});

// Store/update a Live Activity push token by activityId
export const registerLiveActivityToken = mutation({
  args: {
    activityId: v.string(),
    token: v.string(),
    deviceToken: v.string(),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("liveActivityUpdates")
      .filter((q) => q.eq(q.field("activityId"), args.activityId))
      .first();

    const doc = {
      deviceToken: args.deviceToken,
      activityId: args.activityId,
      token: args.token,
      updatedAt: Date.now(),
    } as const;

    if (existing) {
      await ctx.db.patch(existing._id, doc);
      return { success: true, updated: true } as const;
    }
    await ctx.db.insert("liveActivityUpdates", doc);
    return { success: true, created: true } as const;
  },
});

// Store/update a Live Activity push-to-start token per user (iOS 17.2+)
export const registerLiveActivityStartToken = mutation({
  args: {
    deviceToken: v.string(),
    token: v.string(),
    userId: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("liveActivityStartTokens")
      .filter((q) => q.eq(q.field("deviceToken"), args.deviceToken))
      .first();

    const doc = {
      deviceToken: args.deviceToken,
      token: args.token,
      userId: args.userId ?? null,
      updatedAt: Date.now(),
    } as const;

    if (existing) {
      await ctx.db.patch(existing._id, doc);
      return { success: true, updated: true } as const;
    }
    await ctx.db.insert("liveActivityStartTokens", doc);
    return { success: true, created: true } as const;
  },
});
