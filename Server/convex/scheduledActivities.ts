import { v } from "convex/values";
import {
  mutation,
  internalMutation,
  internalAction,
  internalQuery,
} from "./_generated/server";
import { internal, api } from "./_generated/api";

// Queue a Live Activity to start at a specific time
export const queueLiveActivityStart = mutation({
  args: {
    deviceToken: v.string(),
    scheduledStartTime: v.number(),
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
  },
  handler: async (ctx, args) => {
    // Fetch the latest push-to-start token for this device
    const startTokenRecord = await ctx.db
      .query("liveActivityStartTokens")
      .withIndex("by_deviceToken", (q) => q.eq("deviceToken", args.deviceToken))
      .first();

    if (!startTokenRecord) {
      throw new Error("No push-to-start token found for device");
    }

    // Insert the scheduled activity record
    const activityId = await ctx.db.insert("scheduledLiveActivities", {
      deviceToken: args.deviceToken,
      startToken: startTokenRecord.token,
      scheduledStartTime: args.scheduledStartTime,
      trainName: args.trainName,
      fromStation: args.fromStation,
      destinationStation: args.destinationStation,
      status: "pending",
      createdAt: Date.now(),
    });

    // Schedule the actual start action
    const delayMs = args.scheduledStartTime - Date.now();
    if (delayMs > 0) {
      await ctx.scheduler.runAfter(
        delayMs,
        internal.scheduledActivities.executeScheduledStart,
        { activityId }
      );
    }

    return "ok";
  },
});

// Internal action to execute the scheduled start
export const executeScheduledStart = internalAction({
  args: { activityId: v.id("scheduledLiveActivities") },
  handler: async (ctx, args) => {
    // Fetch the activity record
    const activity = await ctx.runQuery(
      internal.scheduledActivities.getActivity,
      {
        activityId: args.activityId,
      }
    );

    if (!activity || activity.status !== "pending") {
      return; // Activity was cancelled or already processed
    }

    try {
      // TODO: Replace hardcoded seat class with actual user data
      const result = await ctx.runAction(api.push.startLiveActivity, {
        startToken: activity.startToken,
        attributes: {
          trainName: activity.trainName,
          from: {
            name: activity.fromStation.name,
            code: activity.fromStation.code,
            estimatedTime: activity.fromStation.estimatedTime,
          },
          destination: {
            name: activity.destinationStation.name,
            code: activity.destinationStation.code,
            estimatedTime: activity.destinationStation.estimatedTime,
          },
          seatClass: {
            kind: "economy", // TODO: Replace with actual seat class
            number: 1, // TODO: Replace with actual seat number
          },
          seatNumber: "1A", // TODO: Replace with actual seat number
        },
        contentState: {
          journeyState: "beforeBoarding",
        },
        alert: {
          title: "Perjalanan Dimulai",
          body: `${activity.trainName} ke ${activity.destinationStation.name}`,
        },
      });

      if (result.success) {
        await ctx.runMutation(internal.scheduledActivities.markAsStarted, {
          activityId: args.activityId,
        });
      } else {
        await ctx.runMutation(internal.scheduledActivities.markAsFailed, {
          activityId: args.activityId,
        });
      }
    } catch (error) {
      await ctx.runMutation(internal.scheduledActivities.markAsFailed, {
        activityId: args.activityId,
      });
    }
  },
});

// Internal query to get activity by ID
export const getActivity = internalQuery({
  args: { activityId: v.id("scheduledLiveActivities") },
  handler: async (ctx, args) => {
    return await ctx.db.get(args.activityId);
  },
});

// Internal mutation to mark activity as started
export const markAsStarted = internalMutation({
  args: { activityId: v.id("scheduledLiveActivities") },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.activityId, { status: "started" });
  },
});

// Internal mutation to mark activity as failed
export const markAsFailed = internalMutation({
  args: { activityId: v.id("scheduledLiveActivities") },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.activityId, { status: "failed" });
  },
});

// Cancel pending scheduled activities for a device
export const cancelScheduledActivity = mutation({
  args: {
    deviceToken: v.string(),
  },
  handler: async (ctx, args) => {
    const activities = await ctx.db
      .query("scheduledLiveActivities")
      .withIndex("by_deviceToken", (q) => q.eq("deviceToken", args.deviceToken))
      .filter((q) => q.eq(q.field("status"), "pending"))
      .collect();

    for (const activity of activities) {
      await ctx.db.patch(activity._id, { status: "cancelled" });
    }
    return "ok";
  },
});
