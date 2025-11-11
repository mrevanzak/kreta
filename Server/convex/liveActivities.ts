import {
  internalAction,
  internalMutation,
  internalQuery,
  mutation,
} from "./_generated/server";
import { v } from "convex/values";
import { api, internal } from "./_generated/api";
import type { Id } from "./_generated/dataModel";

type ScheduledId = Id<"_scheduled_functions"> | null;

export const scheduleStateUpdates = mutation({
  args: {
    activityId: v.string(),
    trainName: v.string(),
    departureTime: v.union(v.number(), v.null()),
    arrivalTime: v.union(v.number(), v.null()),
    arrivalLeadTimeMs: v.number(),
  },
  handler: async (
    ctx,
    args
  ): Promise<{
    departureScheduled: boolean;
    arrivalScheduled: boolean;
  }> => {
    const now = Date.now();

    const existing = await ctx.db
      .query("liveActivitySchedules")
      .withIndex("by_activityId", (q) => q.eq("activityId", args.activityId))
      .first();

    const cancelScheduledJob = async (
      scheduledId: ScheduledId,
      label: "departure" | "arrival"
    ) => {
      if (!scheduledId) {
        return;
      }

      try {
        await ctx.scheduler.cancel(scheduledId);
      } catch (error) {
        console.warn(
          `[liveActivities] Failed to cancel ${label} schedule ${scheduledId}`,
          error
        );
      }
    };

    if (existing?.departureSchedulerId) {
      await cancelScheduledJob(existing.departureSchedulerId, "departure");
    }

    if (existing?.arrivalSchedulerId) {
      await cancelScheduledJob(existing.arrivalSchedulerId, "arrival");
    }

    let departureSchedulerId: ScheduledId = null;
    let arrivalSchedulerId: ScheduledId = null;

    if (args.departureTime !== null) {
      if (args.departureTime <= now) {
        await ctx.scheduler.runAfter(
          0,
          internal.liveActivities.sendStateUpdate,
          {
            activityId: args.activityId,
            journeyState: "onBoard",
            trainName: args.trainName,
          }
        );
      } else {
        departureSchedulerId = await ctx.scheduler.runAt(
          args.departureTime,
          internal.liveActivities.sendStateUpdate,
          {
            activityId: args.activityId,
            journeyState: "onBoard",
            trainName: args.trainName,
          }
        );
      }
    }

    if (args.arrivalTime !== null) {
      const target = Math.max(args.arrivalTime - args.arrivalLeadTimeMs, now);

      if (target <= now) {
        await ctx.scheduler.runAfter(
          0,
          internal.liveActivities.sendStateUpdate,
          {
            activityId: args.activityId,
            journeyState: "prepareToDropOff",
            trainName: args.trainName,
          }
        );
      } else {
        arrivalSchedulerId = await ctx.scheduler.runAt(
          target,
          internal.liveActivities.sendStateUpdate,
          {
            activityId: args.activityId,
            journeyState: "prepareToDropOff",
            trainName: args.trainName,
          }
        );
      }
    }

    const doc = {
      activityId: args.activityId,
      trainName: args.trainName,
      departureTime: args.departureTime,
      arrivalTime: args.arrivalTime,
      arrivalLeadTimeMs: args.arrivalLeadTimeMs,
      departureSchedulerId,
      arrivalSchedulerId,
      updatedAt: now,
    } as const;

    if (existing) {
      await ctx.db.patch(existing._id, doc);
    } else {
      await ctx.db.insert("liveActivitySchedules", doc);
    }

    return {
      departureScheduled: departureSchedulerId !== null,
      arrivalScheduled: arrivalSchedulerId !== null,
    } as const;
  },
});

export const sendStateUpdate = internalAction({
  args: {
    activityId: v.string(),
    journeyState: v.union(
      v.literal("beforeBoarding"),
      v.literal("onBoard"),
      v.literal("prepareToDropOff")
    ),
    trainName: v.string(),
  },
  handler: async (ctx, args) => {
    const tokenRecord = await ctx.runQuery(
      internal.liveActivities.getTokenRecord,
      {
        activityId: args.activityId,
      }
    );

    if (!tokenRecord) {
      console.warn(
        `[liveActivities] Missing push token for activity ${args.activityId}, unable to send ${args.journeyState} update`
      );
      return;
    }

    await ctx.runAction(api.push.updateLiveActivity, {
      activityToken: tokenRecord.token,
      contentState: {
        journeyState: args.journeyState,
      },
    });

    await ctx.runMutation(internal.liveActivities.markTokenTouched, {
      tokenId: tokenRecord._id,
    });
  },
});

export const getTokenRecord = internalQuery({
  args: {
    activityId: v.string(),
  },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("liveActivityUpdates")
      .withIndex("by_activityId", (q) => q.eq("activityId", args.activityId))
      .first();
  },
});

export const markTokenTouched = internalMutation({
  args: {
    tokenId: v.id("liveActivityUpdates"),
  },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.tokenId, {
      updatedAt: Date.now(),
    });
  },
});
