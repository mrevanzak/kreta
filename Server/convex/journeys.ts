import { v } from "convex/values";
import { query } from "./_generated/server";
import { normalizeTimeToDate, normalizeArrivalTime } from "./utils/dateHelpers";

// Deprecated: Prevent full scans over trainJourneys
export const list = query({
  args: {},
  handler: async () => {
    throw new Error(
      "journeys:list is deprecated; use journeys:projectedForRoute."
    );
  },
});

// Compact list DTO for UI list rendering
type ProjectedListItem = {
  id: string; // stable per train and segment window (trainId-based)
  trainId: string;
  code: string;
  name: string;
  fromStationId: string;
  toStationId: string;
  segmentDeparture: number;
  segmentArrival: number;
  routeId?: string;
  // Optional server-provided enrichment fields for client convenience
  fromStationName?: string;
  toStationName?: string;
  fromStationCode?: string;
  toStationCode?: string;
  durationMinutes?: number;
};

// Returns compact items per train that connects departure -> arrival.
export const projectedForRoute = query({
  args: {
    departureStationId: v.string(),
    arrivalStationId: v.string(),
    selectedDate: v.optional(v.number()), // milliseconds since epoch
  },
  handler: async (ctx, args): Promise<ProjectedListItem[]> => {
    // Default to current date if not provided
    const selectedDateMs = args.selectedDate ?? Date.now();
    // 1) Small set of candidate trains using stationConnections
    const connection = await ctx.db
      .query("stationConnections")
      .withIndex("by_station_connected", (q) =>
        q
          .eq("stationId", args.departureStationId)
          .eq("connectedStationId", args.arrivalStationId)
      )
      .unique();

    if (!connection) return [];

    // Fetch station details once for enrichment fields
    const [fromStation, toStation] = await Promise.all([
      ctx.db
        .query("stations")
        .withIndex("by_customId", (q) => q.eq("id", args.departureStationId))
        .unique(),
      ctx.db
        .query("stations")
        .withIndex("by_customId", (q) => q.eq("id", args.arrivalStationId))
        .unique(),
    ]);

    // 2) For each trainId, read journey rows by train ordered by departureTime
    const results: ProjectedListItem[] = [];
    for (const trainId of connection.trainIds) {
      const rows = await ctx.db
        .query("trainJourneys")
        .withIndex("by_trainId_departure", (q) => q.eq("trainId", trainId))
        .collect();

      if (rows.length === 0) continue;
      // rows are ordered by departureTime due to the composite index
      let fromIdx = -1;
      let toIdx = -1;

      for (let i = 0; i < rows.length; i++) {
        const rowI = rows[i];
        if (!rowI) continue;
        if (rowI.stationId === args.departureStationId) {
          fromIdx = i;
          break;
        }
      }
      if (fromIdx >= 0) {
        for (let j = fromIdx + 1; j < rows.length; j++) {
          const rowJ = rows[j];
          if (!rowJ) continue;
          if (rowJ.stationId === args.arrivalStationId) {
            toIdx = j;
            break;
          }
        }
      }

      if (fromIdx >= 0 && toIdx > fromIdx) {
        const fromRow = rows[fromIdx]!;
        const toRow = rows[toIdx]!;

        // Normalize departure time to selected date
        const normalizedDeparture = normalizeTimeToDate(
          fromRow.departureTime,
          selectedDateMs
        );

        // Normalize arrival time, handling next-day arrivals
        const normalizedArrival = normalizeArrivalTime(
          normalizedDeparture,
          toRow.arrivalTime,
          selectedDateMs
        );

        const durationMinutes = Math.max(
          0,
          Math.round((normalizedArrival - normalizedDeparture) / 60000)
        );

        results.push({
          id: `${trainId}`,
          trainId,
          code: fromRow.trainCode,
          name: fromRow.trainName,
          fromStationId: fromRow.stationId,
          toStationId: toRow.stationId,
          segmentDeparture: Math.round(normalizedDeparture),
          segmentArrival: Math.round(normalizedArrival),
          // Use toRow.routeId because the routeId on a station row represents
          // the route that connects TO that station (ending at that station)
          routeId: toRow.routeId ?? undefined,
          fromStationName: fromStation?.name ?? undefined,
          toStationName: toStation?.name ?? undefined,
          fromStationCode: fromStation?.code ?? undefined,
          toStationCode: toStation?.code ?? undefined,
          durationMinutes,
        });
      }
    }

    return results;
  },
});

// Detailed segments for a single train, ordered by departure
export const segmentsForTrain = query({
  args: {
    trainId: v.string(),
    selectedDate: v.optional(v.number()), // milliseconds since epoch
  },
  handler: async (ctx, { trainId, selectedDate }) => {
    // Default to current date if not provided
    const selectedDateMs = selectedDate ?? Date.now();

    const rows = await ctx.db
      .query("trainJourneys")
      .withIndex("by_trainId_departure", (q) => q.eq("trainId", trainId))
      .collect();

    // Normalize all times to selected date, handling next-day arrivals
    const normalizedRows: Array<{
      stationId: string;
      arrivalTime: number;
      departureTime: number;
      trainCode: string;
      trainName: string;
      routeId: string | null;
    }> = [];

    let previousDeparture: number | null = null;

    for (const r of rows) {
      // Normalize departure time to selected date
      const normalizedDeparture = normalizeTimeToDate(
        r.departureTime,
        selectedDateMs
      );

      // Normalize arrival time relative to this station's departure
      // For segments, arrival time is when the train arrives at this station,
      // which should be compared with its own departure (if departure exists)
      // or previous station's departure for continuity
      const normalizedArrival =
        previousDeparture !== null
          ? normalizeArrivalTime(
              previousDeparture,
              r.arrivalTime,
              selectedDateMs
            )
          : normalizeTimeToDate(r.arrivalTime, selectedDateMs);

      // Update previousDeparture for next iteration
      previousDeparture = normalizedDeparture;

      normalizedRows.push({
        stationId: r.stationId,
        arrivalTime: Math.round(normalizedArrival),
        departureTime: Math.round(normalizedDeparture),
        trainCode: r.trainCode,
        trainName: r.trainName,
        routeId: r.routeId,
      });
    }

    return normalizedRows;
  },
});
