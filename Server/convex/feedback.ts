import { query, mutation } from "convex/server";
import { v } from "convex/values";

export const list = query({
  handler: async (ctx) => {
    const feedbackDocs = await ctx.db.query("feedback").collect();

    const results = await Promise.all(
      feedbackDocs.map(async (f) => {
        const votes = await ctx.db
          .query("votes")
          .withIndex("by_feedbackId", (q) => q.eq("feedbackId", f._id))
          .collect();

        return {
          _id: f._id,
          title: f.title,
          description: f.description,
          email: f.email,
          status: f.status,
          createdAt: f.createdAt,
          voteCount: votes.length,
        };
      })
    );

    // Sort by createdAt desc by default so newest appear first
    results.sort((a, b) => b.createdAt - a.createdAt);
    return results;
  },
});

export const create = mutation({
  args: {
    title: v.string(),
    description: v.string(),
    email: v.union(v.string(), v.null()),
    deviceToken: v.string(),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    const feedbackId = await ctx.db.insert("feedback", {
      title: args.title,
      description: args.description,
      email: args.email,
      status: "pending",
      createdAt: now,
    });

    // Creator implicitly votes once
    await ctx.db.insert("votes", {
      feedbackId,
      deviceToken: args.deviceToken,
      createdAt: now,
    });

    return { _id: feedbackId };
  },
});

export const toggleVote = mutation({
  args: {
    feedbackId: v.id("feedback"),
    deviceToken: v.string(),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("votes")
      .withIndex("by_feedback_device", (q) =>
        q.eq("feedbackId", args.feedbackId).eq("deviceToken", args.deviceToken)
      )
      .first();

    if (existing) {
      await ctx.db.delete(existing._id);
      return { voted: false };
    }

    await ctx.db.insert("votes", {
      feedbackId: args.feedbackId,
      deviceToken: args.deviceToken,
      createdAt: Date.now(),
    });
    return { voted: true };
  },
});


