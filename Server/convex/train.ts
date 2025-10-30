import { v } from "convex/values";
import { query } from "./_generated/server";

export const list = query({
  args: {
    departureStationId: v.string(),
    arrivalStationId: v.string(),
  },
  handler: async (ctx, { departureStationId, arrivalStationId }) => {
    // Use precomputed connectivity to get valid trains in correct order
    const connection = await ctx.db
      .query("stationConnections")
      .withIndex("by_station_connected", (q) =>
        q
          .eq("stationId", departureStationId)
          .eq("connectedStationId", arrivalStationId)
      )
      .unique();

    if (!connection) return [] as const;

    // Fetch one journey per trainId to read denormalized code/name
    const trains = await Promise.all(
      connection.trainIds.map(async (id: string) => {
        const sample = await ctx.db
          .query("trainJourneys")
          .withIndex("by_trainId", (q) => q.eq("trainId", id))
          .take(1);
        const j = sample[0];
        if (!j) return null;
        return { id, code: j.trainCode, name: j.trainName };
      })
    );
    return trains.filter((t) => t !== null);
  },
});
