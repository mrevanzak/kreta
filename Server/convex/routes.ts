import { query } from "./_generated/server";

// routes:list → normalized route polylines
export const list = query({
  args: {},
  handler: async (ctx) => {
    const routes = await ctx.db.query("routes").collect();
    return routes.map((r) => ({
      id: r.id,
      name: r.id,
      path: r.paths.flat(),
    }));
  },
});
