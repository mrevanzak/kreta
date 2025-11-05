"use node";

import { action, internalAction } from "./_generated/server";
import { v } from "convex/values";
import * as apn from "@parse/node-apn";

// Construct a singleton APNs provider using token-based auth
const apnsKey = (process.env.APNS_KEY ?? "").replace(/\\n/g, "\n");
const apnProvider = new apn.Provider({
  token: {
    key: apnsKey,
    keyId: process.env.APNS_KEY_ID ?? "",
    teamId: process.env.APNS_TEAM_ID ?? "",
  },
  production: process.env.APNS_PRODUCTION === "true",
});

const contentState = v.object({
  journeyState: v.union(
    v.literal("beforeBoarding"),
    v.literal("onBoard"),
    v.literal("prepareToDropOff")
  ),
});

// Trigger a standard APNs alert push to a specific device token
export const triggerPush = action({
  args: {
    deviceToken: v.string(),
    title: v.string(),
    subtitle: v.optional(v.string()),
    body: v.string(),
  },
  handler: async (_ctx, args) => {
    const bundleId = process.env.BUNDLE_ID ?? "";
    if (!bundleId) {
      return { success: false, error: "Missing BUNDLE_ID env var" } as const;
    }
    if (!apnsKey || !(process.env.APNS_KEY_ID && process.env.APNS_TEAM_ID)) {
      return { success: false, error: "Missing APNs token env vars" } as const;
    }

    const note = new apn.Notification();
    note.topic = bundleId;
    note.pushType = "alert";
    note.alert = {
      title: args.title,
      subtitle: args.subtitle,
      body: args.body,
    };

    try {
      const response = await apnProvider.send(note, args.deviceToken);
      // @parse/node-apn returns an object with sent/failed arrays
      if (response.sent && response.sent.length > 0) {
        return { success: true, status: 200, apnsId: note.id } as const;
      }
      const firstFailure = response.failed?.[0];
      const status = firstFailure?.status ?? 500;
      const reason =
        firstFailure?.response?.reason ?? firstFailure?.error?.message;
      return {
        success: false,
        error: String(reason ?? "Unknown APNs error"),
        status,
        apnsId: note.id,
      } as const;
    } catch (err: unknown) {
      return {
        success: false,
        error: String(err instanceof Error ? err.message : err),
      } as const;
    }
  },
});

// Start a Live Activity remotely (iOS 17.2+) using APNs "liveactivity" push type
// This requires the app's bundle ID to be configured and the device to have provided
// a push-to-start token previously (stored via `registrations.registerLiveActivityStartToken`).
export const startLiveActivity = action({
  args: {
    startToken: v.string(),
    // Attributes matching TrainActivityAttributes in the client
    attributes: v.object({
      trainName: v.string(),
      from: v.object({
        name: v.string(),
        code: v.string(),
        estimatedTime: v.union(v.number(), v.null()),
      }),
      destination: v.object({
        name: v.string(),
        code: v.string(),
        estimatedTime: v.union(v.number(), v.null()),
      }),
      // seatClass: v.object({
      //   kind: v.union(
      //     v.literal("economy"),
      //     v.literal("business"),
      //     v.literal("executive")
      //   ),
      //   number: v.number(),
      // }),
      // seatNumber: v.string(),
    }),
    // Content state matching TrainActivityAttributes.ContentState
    contentState,
    alert: v.object({
      title: v.string(),
      subtitle: v.optional(v.string()),
      body: v.string(),
    }),
  },
  handler: async (ctx, args) => {
    const bundleId = process.env.BUNDLE_ID ?? "";
    if (!bundleId) {
      return { success: false, error: "Missing BUNDLE_ID env var" } as const;
    }
    if (!apnsKey || !(process.env.APNS_KEY_ID && process.env.APNS_TEAM_ID)) {
      return { success: false, error: "Missing APNs token env vars" } as const;
    }

    // Convert SeatClass to Swift Codable enum payload
    const encodeSeatClass = (seat: {
      kind: "economy" | "business" | "executive";
      number: number;
    }) => {
      const payloadKey: Record<typeof seat.kind, string> = {
        economy: "economy",
        business: "business",
        executive: "executive",
      } as const;
      const key = payloadKey[seat.kind];
      return { [key]: { number: seat.number } } as const;
    };

    // Compose APNs Live Activity start payload
    const attributes = {
      trainName: args.attributes.trainName,
      from: args.attributes.from,
      destination: args.attributes.destination,
      // seatClass: encodeSeatClass(args.attributes.seatClass),
      // seatNumber: args.attributes.seatNumber,
    } as const;

    const contentState = args.contentState;

    const note = new apn.Notification();
    note.topic = `${bundleId}.push-type.liveactivity`;
    note.pushType = "liveactivity";
    note.expiry = Math.floor(Date.now() / 1000) + 3600; // Expires 1 hour from now.
    note.aps["content-state"] = contentState;
    note.aps.event = "start";
    note.aps.timestamp = Math.floor(Date.now() / 1000);
    note.aps["stale-date"] = Math.floor(Date.now() / 1000) + 8 * 3600; // Expires 8 hour from now.
    // Inform ActivityKit of the attributes type and initial values
    note.aps["attributes-type"] = "TrainActivityAttributes";
    note.aps.attributes = attributes;
    note.alert = args.alert;

    try {
      const response = await apnProvider.send(note, args.startToken);
      if (response.sent && response.sent.length > 0) {
        return { success: true, status: 200, apnsId: note.id } as const;
      }
      const firstFailure = response.failed?.[0];
      const status = firstFailure?.status ?? 500;
      const reason =
        firstFailure?.response?.reason ?? firstFailure?.error?.message;
      return {
        success: false,
        error: String(reason ?? "Unknown APNs error"),
        status,
        apnsId: note.id,
      } as const;
    } catch (err: unknown) {
      return {
        success: false,
        error: String(err instanceof Error ? err.message : err),
      } as const;
    }
  },
});

// Send a trip reminder notification with deeplink payload
// This is called internally by the notifications scheduler
export const sendTripReminderPush = internalAction({
  args: {
    deviceToken: v.string(),
    title: v.string(),
    body: v.string(),
    deeplink: v.string(),
    trainId: v.string(),
  },
  handler: async (_ctx, args) => {
    const bundleId = process.env.BUNDLE_ID ?? "";
    if (!bundleId) {
      return { success: false, error: "Missing BUNDLE_ID env var" } as const;
    }
    if (!apnsKey || !(process.env.APNS_KEY_ID && process.env.APNS_TEAM_ID)) {
      return { success: false, error: "Missing APNs token env vars" } as const;
    }

    const note = new apn.Notification();
    note.topic = bundleId;
    note.pushType = "alert";
    note.alert = {
      title: args.title,
      body: args.body,
    };
    note.payload = {
      deeplink: args.deeplink,
      trainId: args.trainId,
    } as Record<string, unknown>;
    note.aps.category = "TRIP_START_FALLBACK";

    try {
      const response = await apnProvider.send(note, args.deviceToken);
      if (response.sent && response.sent.length > 0) {
        return { success: true, status: 200, apnsId: note.id } as const;
      }
      const firstFailure = response.failed?.[0];
      const status = firstFailure?.status ?? 500;
      const reason =
        firstFailure?.response?.reason ?? firstFailure?.error?.message;
      return {
        success: false,
        error: String(reason ?? "Unknown APNs error"),
        status,
        apnsId: note.id,
      } as const;
    } catch (err: unknown) {
      return {
        success: false,
        error: String(err instanceof Error ? err.message : err),
      } as const;
    }
  },
});

// Send an arrival alert push with deeplink payload (ETA - 2 minutes)
export const sendArrivalPush = internalAction({
  args: {
    deviceToken: v.string(),
    title: v.string(),
    body: v.string(),
    deeplink: v.string(),
    stationCode: v.string(),
    stationName: v.string(),
    trainId: v.union(v.string(), v.null()),
  },
  handler: async (_ctx, args) => {
    const bundleId = process.env.BUNDLE_ID ?? "";
    if (!bundleId) {
      return { success: false, error: "Missing BUNDLE_ID env var" } as const;
    }
    if (!apnsKey || !(process.env.APNS_KEY_ID && process.env.APNS_TEAM_ID)) {
      return { success: false, error: "Missing APNs token env vars" } as const;
    }

    const note = new apn.Notification();
    note.topic = bundleId;
    note.pushType = "alert";
    note.alert = {
      title: args.title,
      body: args.body,
    };
    note.payload = {
      deeplink: args.deeplink,
      trainId: args.trainId,
      stationCode: args.stationCode,
      stationName: args.stationName,
    } as Record<string, unknown>;
    note.aps.category = "ARRIVAL_ALERT";

    try {
      const response = await apnProvider.send(note, args.deviceToken);
      if (response.sent && response.sent.length > 0) {
        return { success: true, status: 200, apnsId: note.id } as const;
      }
      const firstFailure = response.failed?.[0];
      const status = firstFailure?.status ?? 500;
      const reason =
        firstFailure?.response?.reason ?? firstFailure?.error?.message;
      return {
        success: false,
        error: String(reason ?? "Unknown APNs error"),
        status,
        apnsId: note.id,
      } as const;
    } catch (err: unknown) {
      return {
        success: false,
        error: String(err instanceof Error ? err.message : err),
      } as const;
    }
  },
});

// Update an existing Live Activity's content state via push notification
export const updateLiveActivity = action({
  args: {
    activityToken: v.string(),
    // Content state matching TrainActivityAttributes.ContentState
    contentState,
  },
  handler: async (ctx, args) => {
    const bundleId = process.env.BUNDLE_ID ?? "";
    if (!bundleId) {
      return { success: false, error: "Missing BUNDLE_ID env var" } as const;
    }
    if (!apnsKey || !(process.env.APNS_KEY_ID && process.env.APNS_TEAM_ID)) {
      return { success: false, error: "Missing APNs token env vars" } as const;
    }

    const contentState = args.contentState;

    const note = new apn.Notification();
    note.topic = `${bundleId}.push-type.liveactivity`;
    note.pushType = "liveactivity";
    note.expiry = Math.floor(Date.now() / 1000) + 3600; // Expires 1 hour from now.
    note.aps["content-state"] = contentState;
    note.aps.event = "update";
    note.aps.timestamp = Math.floor(Date.now() / 1000);

    try {
      const response = await apnProvider.send(note, args.activityToken);
      if (response.sent && response.sent.length > 0) {
        return { success: true, status: 200, apnsId: note.id } as const;
      }
      const firstFailure = response.failed?.[0];
      const status = firstFailure?.status ?? 500;
      const reason =
        firstFailure?.response?.reason ?? firstFailure?.error?.message;
      return {
        success: false,
        error: String(reason ?? "Unknown APNs error"),
        status,
        apnsId: note.id,
      } as const;
    } catch (err: unknown) {
      return {
        success: false,
        error: String(err instanceof Error ? err.message : err),
      } as const;
    }
  },
});
