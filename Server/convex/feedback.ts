import { v } from "convex/values";
import { mutation, query } from "./_generated/server";

// Query: aggregate vote counts and return all feedback
export const list = query({
  handler: async (ctx) => {
    const feedbackItems = await ctx.db.query("feedback").collect();

    // For each feedback item, count votes and return with voteCount
    const feedbackWithVotes = await Promise.all(
      feedbackItems.map(async (item) => {
        const votes = await ctx.db
          .query("votes")
          .withIndex("by_feedbackId", (q) => q.eq("feedbackId", item._id))
          .collect();

        return {
          _id: item._id.toString(),
          title: item.title,
          description: item.description,
          email: item.email,
          status: item.status,
          createdAt: item.createdAt,
          voteCount: votes.length,
        };
      })
    );

    return feedbackWithVotes;
  },
});

// Mutation: create feedback
export const create = mutation({
  args: {
    title: v.string(),
    description: v.string(),
    email: v.union(v.string(), v.null()),
    deviceToken: v.string(),
  },
  handler: async (ctx, args) => {
    const feedbackId = await ctx.db.insert("feedback", {
      title: args.title,
      description: args.description,
      email: args.email,
      status: "pending",
      createdAt: Date.now(),
    });

    // Return ID as string to match Swift model
    return { _id: feedbackId.toString() };
  },
});

// Mutation: toggle vote by device
export const toggleVote = mutation({
  args: {
    feedbackId: v.id("feedback"),
    deviceToken: v.string(),
  },
  handler: async (ctx, args) => {
    // Check if vote already exists via by_feedback_device index
    const existingVote = await ctx.db
      .query("votes")
      .withIndex("by_feedback_device", (q) =>
        q.eq("feedbackId", args.feedbackId).eq("deviceToken", args.deviceToken)
      )
      .first();

    if (existingVote) {
      // Delete if exists
      await ctx.db.delete(existingVote._id);
      return { voted: false };
    } else {
      // Insert if not
      await ctx.db.insert("votes", {
        feedbackId: args.feedbackId,
        deviceToken: args.deviceToken,
        createdAt: Date.now(),
      });
      return { voted: true };
    }
  },
});

