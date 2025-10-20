"use node";

import { action, mutation } from "./_generated/server";
import { v } from "convex/values";

// Store/update a device token associated with a user (optional)
export const registerDevice = mutation({
  args: {
    token: v.string(),
    platform: v.string(),
    userId: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("devices")
      .filter((q) => q.eq(q.field("token"), args.token))
      .first();

    const doc = {
      token: args.token,
      platform: args.platform,
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
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("liveActivities")
      .filter((q) => q.eq(q.field("activityId"), args.activityId))
      .first();

    const doc = {
      activityId: args.activityId,
      token: args.token,
      updatedAt: Date.now(),
    } as const;

    if (existing) {
      await ctx.db.patch(existing._id, doc);
      return { success: true, updated: true } as const;
    }
    await ctx.db.insert("liveActivities", doc);
    return { success: true, created: true } as const;
  },
});

// Store/update a Live Activity push-to-start token per user (iOS 17.2+)
export const registerLiveActivityStartToken = mutation({
  args: {
    token: v.string(),
    userId: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("liveActivityStartTokens")
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
    await ctx.db.insert("liveActivityStartTokens", doc);
    return { success: true, created: true } as const;
  },
});

// Trigger a standard APNs alert push to a specific device token
export const triggerPush = action({
  args: {
    deviceToken: v.string(),
    title: v.string(),
    body: v.string(),
    sandbox: v.optional(v.boolean()),
    apnsTopic: v.optional(v.string()), // Defaults to bundle id
  },
  handler: async (_ctx, args) => {
    const teamId = process.env.APNS_TEAM_ID ?? "";
    const keyId = process.env.APNS_KEY_ID ?? "";
    const privateKey = (process.env.APNS_KEY ?? "").replace(/\\n/g, "\n");
    const bundleId = args.apnsTopic ?? process.env.BUNDLE_ID ?? "";
    const useSandbox =
      args.sandbox ??
      (process.env.APNS_USE_SANDBOX ?? "true").toLowerCase() !== "false";

    if (!teamId || !keyId || !privateKey || !bundleId) {
      return {
        success: false,
        error: "Missing APNs configuration env vars.",
      } as const;
    }

    const payload = {
      aps: {
        alert: { title: args.title, body: args.body },
        sound: "default",
      },
    };

    try {
      const result = await sendApns({
        deviceToken: args.deviceToken,
        payload: JSON.stringify(payload),
        bundleId,
        teamId,
        keyId,
        privateKey,
        sandbox: useSandbox,
        pushType: "alert",
      });
      return {
        success: true,
        apnsId: result.apnsId,
        status: result.status,
      } as const;
    } catch (error: unknown) {
      return {
        success: false,
        error: String(error instanceof Error ? error.message : error),
      } as const;
    }
  },
});

type SendApnsArgs = {
  deviceToken: string;
  payload: string;
  bundleId: string;
  teamId: string;
  keyId: string;
  privateKey: string; // PKCS8 .p8 contents
  sandbox: boolean;
  pushType:
    | "alert"
    | "background"
    | "voip"
    | "complication"
    | "fileprovider"
    | "mdm"
    | "liveactivity";
};

async function sendApns(
  args: SendApnsArgs
): Promise<{ status: number; apnsId?: string; body?: string }> {
  const host = args.sandbox
    ? "api.sandbox.push.apple.com"
    : "api.push.apple.com";
  const path = `/3/device/${args.deviceToken}`;

  const jwt = createApnsJwt({
    teamId: args.teamId,
    keyId: args.keyId,
    privateKey: args.privateKey,
  });

  const http2 = await import("node:http2");
  const client = http2.connect(`https://${host}`);

  return await new Promise((resolve, reject) => {
    client.on("error", (err: Error) => reject(err));

    const apnsTopic =
      args.pushType === "liveactivity"
        ? `${args.bundleId}.push-type.liveactivity`
        : args.bundleId;

    const headers: Record<string, string> = {
      ":method": "POST",
      ":path": path,
      "apns-topic": apnsTopic,
      "apns-push-type": args.pushType,
      authorization: `bearer ${jwt}`,
    };

    const req = client.request(headers);
    let responseData = "";

    req.setEncoding("utf8");
    req.on(
      "response",
      (headers: Record<string, string | number | string[]>) => {
        // Collect APNs-id for debugging
        const apnsIdHeader = headers["apns-id"];
        const apnsId = Array.isArray(apnsIdHeader)
          ? apnsIdHeader[0]
          : (apnsIdHeader as string | undefined);
        const status = Number(headers[":status"] ?? 0);

        req.on("data", (chunk: string) => {
          responseData += chunk;
        });

        req.on("end", () => {
          client.close();
          resolve({ status, apnsId, body: responseData });
        });
      }
    );

    req.on("error", (err: Error) => {
      client.close();
      reject(err);
    });

    req.end(args.payload);
  });
}

function createApnsJwt(params: {
  teamId: string;
  keyId: string;
  privateKey: string;
}): string {
  const header = { alg: "ES256", kid: params.keyId, typ: "JWT" } as const;
  const now = Math.floor(Date.now() / 1000);
  const payload = { iss: params.teamId, iat: now } as const;

  const headerB64 = base64url(JSON.stringify(header));
  const payloadB64 = base64url(JSON.stringify(payload));
  const signingInput = `${headerB64}.${payloadB64}`;

  const crypto = require("node:crypto") as typeof import("node:crypto");
  const signature: Buffer = crypto.sign("sha256", Buffer.from(signingInput), {
    key: params.privateKey,
    format: "pem",
    dsaEncoding: "ieee-p1363",
  });

  const sigB64 = base64url(signature);
  return `${signingInput}.${sigB64}`;
}

function base64url(input: string | Buffer): string {
  const base = (
    typeof input === "string" ? Buffer.from(input) : input
  ).toString("base64");
  return base.replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}
