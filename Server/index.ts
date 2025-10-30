import { ConvexClient } from "convex/browser";
import { api } from "./convex/_generated/api";
import stationsJson from "./stations.json";
import routesJson from "./route-path.json";
import gapekaJson from "./gapeka.json";

const client = new ConvexClient(process.env.CONVEX_URL!);
async function seedStations() {
  const stations = stationsJson.map((val) => ({
    id: val.id.toString(),
    code: val.code,
    name: val.name,
    position: val.position,
    city: val.city,
  }));

  return await client.mutation(api.init.seedStations, { stations });
}

async function seedRoutes() {
  const routes = routesJson.data.map((val) => ({
    id: val.route_id.toString(),
    paths: val.paths.map((path) =>
      path.pos.map((pos) => ({
        latitude: pos[0],
        longitude: pos[1],
      }))
    ),
  }));
  return await client.mutation(api.init.seedRoutes, { routes });
}

const BATCH_SIZE = 10;
async function seedTrainJourneys() {
  const { data } = gapekaJson;
  for (let i = 0; i < data.length; i += BATCH_SIZE) {
    const batch = data.slice(i, i + BATCH_SIZE);
    await Promise.all(
      batch.map(async (train) => {
        await Promise.all([
          ...train.paths.map((path) =>
            client.mutation(api.init.seedTrainJourneys, {
              trainId: train.tr_id.toString(),
              trainCode: train.tr_cd,
              trainName: train.tr_name,

              stationId: path.st_id.toString(),
              arrivalTime: path.arriv_ms,
              departureTime: path.depart_ms,
              routeId: path.route_id ? path.route_id.toString() : null,
            })
          ),
          client.mutation(api.init.seedTrain, {
            id: train.tr_id.toString(),
            code: train.tr_cd,
            name: train.tr_name,
          }),
        ]);
      })
    );
  }
}

type ConnectionKey = string;
type ConnectionAgg = {
  stationId: string;
  connectedStationId: string;
  trainIds: Set<string>;
  earliestDeparture: number;
  latestArrival: number;
};

async function seedStationConnections() {
  const { data } = gapekaJson as any;
  const map = new Map<ConnectionKey, ConnectionAgg>();

  for (const train of data as any[]) {
    const paths = train.paths as any[];
    // For each origin index, connect to all later stations on the same train
    for (let i = 0; i < paths.length; i++) {
      const from = paths[i];
      const fromId = String(from.st_id);
      const fromDep = Number(from.depart_ms ?? from.arriv_ms ?? 0);
      for (let j = i + 1; j < paths.length; j++) {
        const to = paths[j];
        const toId = String(to.st_id);
        const toArr = Number(to.arriv_ms ?? to.depart_ms ?? 0);
        const key = `${fromId}__${toId}`;
        let agg = map.get(key);
        if (!agg) {
          agg = {
            stationId: fromId,
            connectedStationId: toId,
            trainIds: new Set<string>(),
            earliestDeparture: fromDep,
            latestArrival: toArr,
          };
          map.set(key, agg);
        }
        agg.trainIds.add(String(train.tr_id));
        if (fromDep < agg.earliestDeparture) agg.earliestDeparture = fromDep;
        if (toArr > agg.latestArrival) agg.latestArrival = toArr;
      }
    }
  }

  const connections = Array.from(map.values()).map((c) => ({
    stationId: c.stationId,
    connectedStationId: c.connectedStationId,
    trainIds: Array.from(c.trainIds),
    earliestDeparture: c.earliestDeparture,
    latestArrival: c.latestArrival,
  }));

  const CHUNK = 500;
  for (let i = 0; i < connections.length; i += CHUNK) {
    const batch = connections.slice(i, i + CHUNK);
    await client.mutation(api.init.seedStationConnections, {
      connections: batch,
    });
  }
}

const [stationsResult, routesResult, trainJourneysResult, connectionsResult] =
  await Promise.allSettled([
    seedStations(),
    seedRoutes(),
    seedTrainJourneys(),
    seedStationConnections(),
  ]);
console.log(
  stationsResult.status,
  routesResult.status,
  trainJourneysResult.status,
  connectionsResult.status
);
if (stationsResult.status === "fulfilled") {
  console.log(stationsResult.value);
}
if (routesResult.status === "fulfilled") {
  console.log(routesResult.value);
}
if (trainJourneysResult.status === "fulfilled") {
  console.log(trainJourneysResult.value);
}
if (connectionsResult.status === "fulfilled") {
  console.log(connectionsResult.value);
}
await client.close();
