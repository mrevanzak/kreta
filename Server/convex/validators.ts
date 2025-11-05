import { v } from "convex/values";

export const stationValidator = v.object({
  name: v.string(),
  code: v.string(),
  estimatedTime: v.union(v.number(), v.null()),
});

export const contentStateValidator = v.object({
  journeyState: v.union(
    v.literal("beforeBoarding"),
    v.literal("onBoard"),
    v.literal("prepareToDropOff")
  ),
});
