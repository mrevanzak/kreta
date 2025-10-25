import { query } from "./_generated/server";

export const getLastUpdatedAt = query({
  args: {},
  handler: async (ctx) => {
    const gapeka = await ctx.db
      .query("gapeka")
      .withIndex("by_lastUpdatedAt")
      .order("desc")
      .first();
    return gapeka?.lastUpdatedAt;
  },
});
