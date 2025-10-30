import { v } from "convex/values";
import { query } from "./_generated/server";

export const list = query({
  args: {
    departureStationId: v.optional(v.string()),
  },
  handler: async (ctx, { departureStationId }) => {
    if (!departureStationId) {
      return await ctx.db.query("stations").collect();
    }

    // Use precomputed connectivity
    const connections = await ctx.db
      .query("stationConnections")
      .withIndex("by_stationId", (q) => q.eq("stationId", departureStationId))
      .collect();

    if (connections.length === 0) return [] as const;

    const arrivals = await Promise.all(
      connections.map((c) =>
        ctx.db
          .query("stations")
          .withIndex("by_customId", (q) => q.eq("id", c.connectedStationId))
          .unique()
      )
    );
    return arrivals.filter((s) => s !== null);
  },
});
