"use node";

import * as apn from "@parse/node-apn";

type ValidateResult =
  | { ok: true; bundleId: string }
  | { ok: false; error: string };

let cachedProvider: apn.Provider | null = null;

export function validateApnsEnvironment(): ValidateResult {
  const bundleId = process.env.BUNDLE_ID ?? "";
  const apnsKey = process.env.APNS_KEY ?? "";
  const keyId = process.env.APNS_KEY_ID ?? "";
  const teamId = process.env.APNS_TEAM_ID ?? "";

  if (!bundleId) return { ok: false, error: "Missing BUNDLE_ID env var" };
  if (!apnsKey || !keyId || !teamId)
    return { ok: false, error: "Missing APNs token env vars" };

  return { ok: true, bundleId };
}

type ApnsProvider = {
  sendNotification: (
    note: apn.Notification,
    token: string
  ) => ReturnType<typeof sendApnsNotification>;
};
export function buildApnsProvider(): ApnsProvider {
  if (cachedProvider)
    return {
      sendNotification: async (note, token) => {
        if (!cachedProvider) {
          throw new Error("APNs provider not initialized");
        }
        return await sendApnsNotification(cachedProvider, note, token);
      },
    };

  const apnsKey = (process.env.APNS_KEY ?? "").replace(/\\n/g, "\n");
  cachedProvider = new apn.Provider({
    token: {
      key: apnsKey,
      keyId: process.env.APNS_KEY_ID ?? "",
      teamId: process.env.APNS_TEAM_ID ?? "",
    },
    production: process.env.APNS_PRODUCTION === "true",
  });

  return {
    sendNotification: async (note, token) => {
      if (!cachedProvider) {
        throw new Error("APNs provider not initialized");
      }
      return await sendApnsNotification(cachedProvider, note, token);
    },
  };
}

export async function sendApnsNotification(
  provider: apn.Provider,
  note: apn.Notification,
  token: string
): Promise<
  | { success: true; status?: number; apnsId?: string }
  | { success: false; error: string; status?: number; apnsId?: string }
> {
  try {
    const response = await provider.send(note, token);
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
}
