import { query } from "./_generated/server";

export const get = query({
  args: {},
  handler: async (ctx) => {
    const stations = await ctx.db.query("stations").collect();
    return stations;
  },
});
