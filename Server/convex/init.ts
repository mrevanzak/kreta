import { v } from "convex/values";
import { mutation } from "./_generated/server";

export const seedStations = mutation({
  args: {
    stations: v.any(),
  },
  handler: async (ctx, args) => {
    for (const station of args.stations) {
      await ctx.db.insert("stations", station);
    }
    return "ok" as const;
  },
});

export const seedRoutes = mutation({
  args: {
    routes: v.any(),
  },
  handler: async (ctx, args) => {
    for (const route of args.routes) {
      await ctx.db.insert("routes", route);
    }
    return "ok" as const;
  },
});

export const seedTrain = mutation({
  args: v.any(),
  handler: async (ctx, args) => {
    await ctx.db.insert("trains", args);
    return "ok" as const;
  },
});

export const seedTrainJourneys = mutation({
  args: v.any(),
  handler: async (ctx, args) => {
    await ctx.db.insert("trainJourneys", args);
    return "ok" as const;
  },
});

export const seedStationConnections = mutation({
  args: {
    connections: v.any(),
  },
  handler: async (ctx, { connections }) => {
    for (const conn of connections) {
      await ctx.db.insert("stationConnections", conn);
    }
    return "ok" as const;
  },
});
