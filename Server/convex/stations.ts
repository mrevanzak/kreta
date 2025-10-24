import { query } from "./_generated/server";

export const getStations = query({
  args: {},
  handler: async (ctx) => {
    const stations = await ctx.db.query("stations").collect();
    return stations;
  },
});
