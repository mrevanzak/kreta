import { internalQuery, query } from "./_generated/server";

// in seconds
const DEFAULTS = {
  tripReminder: 10 * 60,
  arrivalAlert: 2 * 60,
} as const;

export const get = query({
  args: {},
  handler: async (ctx) => {
    const records = await ctx.db.query("appConfig").collect();

    return Object.fromEntries(
      Object.keys(DEFAULTS).map((key) => [
        key,
        records.find((r) => r.configKey === key)?.value ??
          DEFAULTS[key as keyof typeof DEFAULTS],
      ])
    );
  },
});

export const getArrivalAlert = internalQuery({
  args: {},
  handler: async (ctx) => {
    const record = await ctx.db
      .query("appConfig")
      .withIndex("by_configKey", (q) => q.eq("configKey", "arrivalAlert"))
      .unique();
    return record?.value ?? DEFAULTS.arrivalAlert;
  },
});
