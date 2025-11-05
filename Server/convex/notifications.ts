import { internalAction, mutation } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import type { Id } from "./_generated/dataModel";

// Schedule a trip reminder notification to be sent 10 minutes before departure
export const scheduleTripReminder = mutation({
  args: {
    deviceToken: v.string(),
    trainId: v.string(),
    trainName: v.string(),
    departureTime: v.number(), // milliseconds since epoch
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
    // Calculate notification time: 10 minutes before departure
    const notificationTimeMs = args.departureTime - 10 * 60 * 1000;
    const nowMs = Date.now();

    // If the notification time is in the past, don't schedule
    if (notificationTimeMs <= nowMs) {
      throw new Error(
        "Cannot schedule notification: notification time is in the past"
      );
    }

    // Schedule the sendTripReminder action to run at the calculated time
    const schedulerId: Id<"_scheduled_functions"> = await ctx.scheduler.runAt(
      notificationTimeMs,
      internal.notifications.sendTripReminder,
      {
        deviceToken: args.deviceToken,
        trainId: args.trainId,
        trainName: args.trainName,
        fromStation: args.fromStation,
        destinationStation: args.destinationStation,
      }
    );

    return schedulerId;
  },
});

// Internal action that sends the trip reminder notification
// This is scheduled by scheduleTripReminder and called by the scheduler
export const sendTripReminder = internalAction({
  args: {
    deviceToken: v.string(),
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
  },
  handler: async (ctx, args) => {
    // Construct the deeplink
    const deeplink = `kreta://trip/start?trainId=${encodeURIComponent(
      args.trainId
    )}`;

    // Construct notification title and body
    const title = "Perjalanan akan dimulai";
    const body = `Kereta ${args.trainName} akan berangkat dalam 10 menit dari ${args.fromStation.name}. Buka aplikasi untuk mulai melacak perjalanan.`;

    // Call the push action to send the notification with deeplink payload
    await ctx.runAction(internal.push.sendTripReminderPush, {
      deviceToken: args.deviceToken,
      title,
      body,
      deeplink,
      trainId: args.trainId,
    });
  },
});

// Cancel a scheduled trip reminder notification
export const cancelTripReminder = mutation({
  args: {
    schedulerId: v.id("_scheduled_functions"),
  },
  handler: async (ctx, args) => {
    await ctx.scheduler.cancel(args.schedulerId);
    return "ok" as const;
  },
});

// Schedule an arrival alert 2 minutes before arrival time
export const scheduleArrivalAlert = mutation({
  args: {
    deviceToken: v.string(),
    trainId: v.union(v.string(), v.null()),
    trainName: v.string(),
    arrivalTime: v.number(), // milliseconds since epoch
    destinationStation: v.object({
      name: v.string(),
      code: v.string(),
      estimatedTime: v.union(v.number(), v.null()),
    }),
  },
  handler: async (ctx, args) => {
    const notificationTimeMs = args.arrivalTime - 2 * 60 * 1000;
    const nowMs = Date.now();

    if (notificationTimeMs <= nowMs) {
      throw new Error(
        "Cannot schedule arrival alert: notification time is in the past"
      );
    }

    const schedulerId: Id<"_scheduled_functions"> = await ctx.scheduler.runAt(
      notificationTimeMs,
      internal.notifications.sendArrivalAlert,
      {
        deviceToken: args.deviceToken,
        trainId: args.trainId,
        trainName: args.trainName,
        destinationStation: args.destinationStation,
      }
    );

    return schedulerId;
  },
});

// Internal action to send the actual arrival alert push
export const sendArrivalAlert = internalAction({
  args: {
    deviceToken: v.string(),
    trainId: v.union(v.string(), v.null()),
    trainName: v.string(),
    destinationStation: v.object({
      name: v.string(),
      code: v.string(),
      estimatedTime: v.union(v.number(), v.null()),
    }),
  },
  handler: async (ctx, args) => {
    const stationName = args.destinationStation.name;
    const stationCode = args.destinationStation.code;
    const deeplink = `kreta://arrival?code=${encodeURIComponent(
      stationCode
    )}&name=${encodeURIComponent(stationName)}`;

    const title = "Segera Turun!";
    const body = `2 menit lagi tiba di ${stationName}`;

    await ctx.runAction(internal.push.sendArrivalPush, {
      deviceToken: args.deviceToken,
      title,
      body,
      deeplink,
      stationCode,
      stationName,
      trainId: args.trainId,
    });
  },
});
