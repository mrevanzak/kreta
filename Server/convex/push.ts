"use node";

import { action } from "./_generated/server";
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
  production: Boolean(process.env.APNS_PRODUCTION),
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
