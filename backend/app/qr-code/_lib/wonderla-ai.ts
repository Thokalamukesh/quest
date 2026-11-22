/* ============================================================
   Wonderla Park AI Concierge powered by Firebase Genkit + Gemini.
   Uses Genkit tool calling (ai.defineTool) so the model decides
   on demand which park data tools to call instead of fetching
   everything upfront, and streams incremental output to Flutter.
============================================================ */

import { genkit, z } from "genkit";
import { googleAI } from "@genkit-ai/google-genai";
import { getPark } from "./store";
import type { DiningOutlet, MediaItem, ParkConfig, ParkMapPlace } from "./types";

export interface AiChatHistoryItem {
  role: "user" | "assistant";
  text: string;
}

export interface AiSuggestedPlace {
  name: string;
  category: string;
  directions?: string;
  directionsUrl?: string;
  action: "directions" | "map";
}

export type AiStreamEvent =
  | { type: "status"; tool: string; label: string }
  | { type: "chunk"; text: string }
  | { type: "places"; items: AiSuggestedPlace[] }
  | { type: "done"; mode: "genkit" | "smart_tools" }
  | { type: "error"; message: string };

const GEMINI_KEY =
  process.env.GEMINI_API_KEY?.trim() ||
  process.env.GOOGLE_API_KEY?.trim() ||
  process.env.GOOGLE_GENAI_API_KEY?.trim() ||
  "";

let _genkitInstance: ReturnType<typeof genkit> | null = null;

function getGenkit() {
  if (!_genkitInstance) {
    _genkitInstance = genkit({
      plugins: [googleAI({ apiKey: GEMINI_KEY })],
    });
  }
  return _genkitInstance;
}

function normalize(value: string | undefined): string {
  return (value ?? "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

function parseMinHeightCm(ride: MediaItem, guidelines: ParkConfig["rideGuidelines"]): number | null {
  const explicit = ride.minHeight?.match(/(\d{2,3})\s*cm/i);
  if (explicit) return Number(explicit[1]);

  const rideNorm = normalize(ride.title);
  for (const g of guidelines ?? []) {
    if (normalize(g.title).includes(rideNorm) && g.minHeight) {
      const m = g.minHeight.match(/(\d{2,3})\s*cm/i);
      if (m) return Number(m[1]);
    }
  }

  const text = `${ride.title} ${ride.description} ${(ride.tags ?? []).join(" ")}`.toLowerCase();
  if (/(kiddie|kids|mini|carousel|flying jumbo|magic mushroom|funky monkey|toy train)/.test(text)) {
    return 85;
  }
  if (/(lazy river|jungle lagoon|wave pool|fun racers|uphill racers|family|crazy cars|rain disco)/.test(text)) {
    return 100;
  }
  if (/(recoil|drop loop|boomerang|harakiri|mission interstellar|maverick|g-fall|drop zone|high thrill|roller coaster)/.test(text)) {
    return 135;
  }
  return 105;
}

function classifyRideCategory(ride: MediaItem): "kids" | "family" | "water" | "thrill" {
  const text = `${ride.title} ${ride.description} ${(ride.tags ?? []).join(" ")}`.toLowerCase();
  if (/(kiddie|kids|carousel|mini express|flying jumbo|magic mushroom|funky monkey)/.test(text)) {
    return "kids";
  }
  if (/(water|slide|river|lagoon|wave|rain|splash|boomerang|harakiri|drop loop|racers)/.test(text)) {
    return "water";
  }
  if (/(recoil|thrill|coaster|drop|maverick|interstellar|g-fall)/.test(text)) {
    return "thrill";
  }
  return "family";
}

function findWaitMinutes(cfg: ParkConfig, rideName: string): number | null {
  const target = normalize(rideName);
  const hit = (cfg.liveWaitTimes ?? []).find((w) => {
    const n = normalize(w.title);
    return n === target || n.includes(target) || target.includes(n);
  });
  return hit ? Number(hit.time) : null;
}

function findMaintenance(cfg: ParkConfig, rideName: string) {
  const target = normalize(rideName);
  return (cfg.maintenanceLog ?? []).find((m) => {
    const n = normalize(m.ride);
    return n === target || n.includes(target) || target.includes(n);
  });
}

function findMapPlace(cfg: ParkConfig, query: string): ParkMapPlace | undefined {
  const target = normalize(query);
  if (!target) return undefined;
  return (cfg.parkMap?.places ?? []).find((p) => {
    const n = normalize(p.name);
    return n === target || n.includes(target) || target.includes(n);
  });
}

function buildPlaceSuggestion(
  name: string,
  category: string,
  cfg: ParkConfig,
  extra?: { directions?: string; directionsUrl?: string },
): AiSuggestedPlace {
  const mapPlace = findMapPlace(cfg, name);
  const dining = (cfg.dining ?? []).find((d) => normalize(d.name) === normalize(name));
  const ride = (cfg.rides ?? []).find((r) => normalize(r.title) === normalize(name));
  const directions =
    extra?.directions?.trim() ||
    mapPlace?.directions?.trim() ||
    dining?.directions?.trim() ||
    ride?.directions?.trim() ||
    undefined;
  const directionsUrl =
    extra?.directionsUrl?.trim() ||
    mapPlace?.directionsUrl?.trim() ||
    dining?.directionsUrl?.trim() ||
    ride?.directionsUrl?.trim() ||
    undefined;
  const hasDir = Boolean(
    directions ||
      directionsUrl ||
      (mapPlace?.lat != null && mapPlace?.lng != null) ||
      (dining?.lat != null && dining?.lng != null),
  );
  return {
    name,
    category,
    directions,
    directionsUrl,
    action: hasDir ? "directions" : "map",
  };
}

function executeRidesTool(
  cfg: ParkConfig,
  args: { heightCm?: number; category?: string; kioskOnly?: boolean },
  suggestedPlaces: Map<string, AiSuggestedPlace>,
) {
  const rides = (cfg.rides ?? []).map((ride) => {
    const minHeightCm = parseMinHeightCm(ride, cfg.rideGuidelines);
    const category = classifyRideCategory(ride);
    const waitMinutes = findWaitMinutes(cfg, ride.title);
    const maint = findMaintenance(cfg, ride.title);
    const eligible =
      args.heightCm == null || minHeightCm == null || args.heightCm >= minHeightCm;
    return {
      title: ride.title,
      category,
      description: ride.description,
      tags: ride.tags ?? [],
      estimatedMinHeightCm: minHeightCm,
      eligibleForHeight: eligible,
      waitMinutes,
      kioskBookingEnabled: Boolean(ride.kioskBookingEnabled),
      operatingStatus: "Operating",
      lastService: maint?.lastService ?? null,
      maintenanceChecks: maint?.checks ?? null,
      directions: ride.directions ?? null,
      directionsUrl: ride.directionsUrl ?? null,
    };
  });

  const filtered = rides.filter((r) => {
    if (args.heightCm != null && !r.eligibleForHeight) return false;
    if (args.category && args.category !== "all" && r.category !== args.category) {
      return false;
    }
    if (args.kioskOnly && !r.kioskBookingEnabled) return false;
    return true;
  });

  filtered.sort((a, b) => (a.waitMinutes ?? 999) - (b.waitMinutes ?? 999));

  for (const r of filtered.slice(0, 4)) {
    suggestedPlaces.set(
      normalize(r.title),
      buildPlaceSuggestion(r.title, r.category, cfg, {
        directions: r.directions ?? undefined,
        directionsUrl: r.directionsUrl ?? undefined,
      }),
    );
  }

  return {
    parkName: cfg.name,
    lastUpdated: cfg.updatedAt,
    totalRidesInPark: rides.length,
    matchingCount: filtered.length,
    heightCmChecked: args.heightCm ?? null,
    rides: filtered,
  };
}

function executeWaitTimesTool(
  cfg: ParkConfig,
  args: { maxWaitMinutes?: number },
  suggestedPlaces: Map<string, AiSuggestedPlace>,
) {
  const waits = (cfg.liveWaitTimes ?? [])
    .map((w) => ({
      title: w.title,
      waitMinutes: Number(w.time),
      description: w.description,
    }))
    .filter((w) => args.maxWaitMinutes == null || w.waitMinutes <= args.maxWaitMinutes)
    .sort((a, b) => a.waitMinutes - b.waitMinutes);

  for (const w of waits.slice(0, 3)) {
    suggestedPlaces.set(normalize(w.title), buildPlaceSuggestion(w.title, "Ride", cfg));
  }
  return { parkName: cfg.name, liveWaitTimes: waits };
}

function executeSchedulesTool(
  cfg: ParkConfig,
  suggestedPlaces: Map<string, AiSuggestedPlace>,
) {
  const waveAndRain = (cfg.waveRainDance ?? []).map((w) => ({
    title: w.title,
    sessions: w.timeSlot ?? [],
    durationMinutes: w.rideDuration,
  }));
  const events = (cfg.events ?? []).map((e) => ({
    title: e.title,
    time: e.time,
    description: e.description,
    tags: e.tags ?? [],
  }));
  for (const w of waveAndRain.slice(0, 2)) {
    suggestedPlaces.set(normalize(w.title), buildPlaceSuggestion(w.title, "Water ride", cfg));
  }
  return { parkName: cfg.name, wavePoolAndRainDance: waveAndRain, events };
}

function executeDiningTool(
  cfg: ParkConfig,
  args: { vegOnly?: boolean; query?: string },
  suggestedPlaces: Map<string, AiSuggestedPlace>,
) {
  const q = normalize(args.query);
  const outlets = (cfg.dining ?? [])
    .map((d: DiningOutlet) => {
      const items = args.vegOnly ? (d.items ?? []).filter((i) => i.veg) : (d.items ?? []);
      return {
        name: d.name,
        cuisine: d.cuisine,
        description: d.description ?? "",
        tags: d.tags ?? [],
        directions: d.directions ?? "",
        directionsUrl: d.directionsUrl ?? "",
        hasPureVegOptions: (d.items ?? []).some((i) => i.veg),
        isPureVeg: (d.items ?? []).length > 0 && (d.items ?? []).every((i) => i.veg),
        dishes: items.map((i) => ({ name: i.name, price: i.price, veg: i.veg })),
      };
    })
    .filter((d) => {
      if (args.vegOnly && d.dishes.length === 0) return false;
      if (q) {
        const hay = normalize(
          `${d.name} ${d.cuisine} ${d.description} ${d.tags.join(" ")} ${d.dishes.map((i) => i.name).join(" ")}`,
        );
        return hay.includes(q);
      }
      return true;
    });

  for (const d of outlets.slice(0, 3)) {
    suggestedPlaces.set(
      normalize(d.name),
      buildPlaceSuggestion(d.name, "Dining", cfg, {
        directions: d.directions,
        directionsUrl: d.directionsUrl,
      }),
    );
  }
  return { parkName: cfg.name, diningOutlets: outlets };
}

function executeMapDirectionsTool(
  cfg: ParkConfig,
  args: { placeName?: string; category?: string },
  suggestedPlaces: Map<string, AiSuggestedPlace>,
) {
  const target = normalize(args.placeName);
  const cat = normalize(args.category);

  const combined: Array<{
    name: string;
    category: string;
    directions: string;
    directionsUrl: string;
    hasGps: boolean;
  }> = [];

  for (const p of cfg.parkMap?.places ?? []) {
    combined.push({
      name: p.name,
      category: p.category,
      directions: p.directions ?? "",
      directionsUrl: p.directionsUrl ?? "",
      hasGps: p.lat != null && p.lng != null,
    });
  }
  for (const d of cfg.dining ?? []) {
    if (!combined.some((c) => normalize(c.name) === normalize(d.name))) {
      combined.push({
        name: d.name,
        category: "Dining",
        directions: d.directions ?? d.description ?? "",
        directionsUrl: d.directionsUrl ?? "",
        hasGps: d.lat != null && d.lng != null,
      });
    }
  }

  const matched = combined.filter((item) => {
    if (target && !normalize(item.name).includes(target) && !target.includes(normalize(item.name))) {
      return false;
    }
    if (cat && !normalize(item.category).includes(cat)) {
      return false;
    }
    return true;
  });

  const results = matched.length > 0 ? matched.slice(0, 6) : combined.slice(0, 6);
  for (const r of results.slice(0, 4)) {
    suggestedPlaces.set(
      normalize(r.name),
      buildPlaceSuggestion(r.name, r.category, cfg, {
        directions: r.directions,
        directionsUrl: r.directionsUrl,
      }),
    );
  }

  return {
    parkName: cfg.name,
    zones: cfg.parkMap?.zones ?? [],
    places: results,
  };
}

function executeGuidelinesTool(cfg: ParkConfig) {
  return {
    parkName: cfg.name,
    rideGuidelines: cfg.rideGuidelines ?? [],
    safetyHygiene: (cfg.safetyHygiene ?? []).map((s) => ({
      title: s.title,
      description: s.description,
    })),
  };
}

async function emitChunksSlowly(
  text: string,
  onEvent: (event: AiStreamEvent) => void,
) {
  // Stream in small natural phrases so Flutter displays tokens progressively.
  const tokens = text.match(/\S+\s*/g) ?? [text];
  const groupSize = 4;
  for (let i = 0; i < tokens.length; i += groupSize) {
    onEvent({ type: "chunk", text: tokens.slice(i, i + groupSize).join("") });
    await new Promise((resolve) => setTimeout(resolve, 22));
  }
}

async function runSmartToolFallback(
  cfg: ParkConfig,
  message: string,
  onEvent: (event: AiStreamEvent) => void,
) {
  const lower = message.toLowerCase();
  const suggestedPlaces = new Map<string, AiSuggestedPlace>();

  const heightMatch = lower.match(/(\d{2,3})\s*(?:cm|centimeter)/i);
  const heightCm = heightMatch ? Number(heightMatch[1]) : undefined;
  const hoursMatch = lower.match(/(\d+)\s*(?:hr|hour)/i);
  const hours = hoursMatch ? Math.min(Math.max(Number(hoursMatch[1]), 1), 8) : undefined;

  const asksPlan = /(plan|itinerary|today|schedule|next \d|suggest|recommend|start)/.test(lower);
  const asksRides = /(ride|coaster|kid|child|thrill|water|height|cm|\bdo\b)/.test(lower) || asksPlan;
  const asksWait = /(wait|queue|crowd|shortest|fast|quick|busy)/.test(lower) || asksPlan;
  const asksFood = /(food|eat|dining|restaurant|lunch|breakfast|veg|biryani|dosa|menu|snack|hungry)/.test(lower);
  const asksMap = /(map|direction|where|locate|route|find|how to reach|how do i get|way to)/.test(lower);
  const asksShows = /(wave|rain|show|event|parade|laser|timing|time)/.test(lower) || asksPlan;
  const asksSafety = /(safe|height|rule|guideline|locker|swimwear|ticket|hygiene)/.test(lower) || heightCm != null;

  const sections: string[] = [];

  if (asksPlan) {
    sections.push(
      `Let's plan your ${hours ? `next ${hours} hours` : "day"} at **${cfg.name}**! First, I'm checking available attractions, live operating status, and queue times.`,
    );
  }

  let ridesData: ReturnType<typeof executeRidesTool> | null = null;
  if (asksRides) {
    onEvent({
      type: "status",
      tool: "getParkRidesAndStatus",
      label: heightCm
        ? `Checking rides safe for ${heightCm} cm & operating status…`
        : "Checking available attractions & operating status…",
    });
    await new Promise((r) => setTimeout(r, 120));
    ridesData = executeRidesTool(cfg, { heightCm }, suggestedPlaces);
  }

  let waitData: ReturnType<typeof executeWaitTimesTool> | null = null;
  if (asksWait) {
    onEvent({
      type: "status",
      tool: "getLiveWaitTimes",
      label: "Checking live ride wait times…",
    });
    await new Promise((r) => setTimeout(r, 100));
    waitData = executeWaitTimesTool(cfg, {}, suggestedPlaces);
  }

  let scheduleData: ReturnType<typeof executeSchedulesTool> | null = null;
  if (asksShows) {
    onEvent({
      type: "status",
      tool: "getWaterAndEventSchedule",
      label: "Checking Wave Pool, Rain Disco & show timings…",
    });
    await new Promise((r) => setTimeout(r, 90));
    scheduleData = executeSchedulesTool(cfg, suggestedPlaces);
  }

  let diningData: ReturnType<typeof executeDiningTool> | null = null;
  if (asksFood) {
    const vegOnly = /(pure veg|\bveg\b|vegetarian)/.test(lower);
    onEvent({
      type: "status",
      tool: "getDiningAndMenus",
      label: vegOnly
        ? "Searching vegetarian restaurants & menus…"
        : "Checking park dining outlets & menus…",
    });
    await new Promise((r) => setTimeout(r, 100));
    diningData = executeDiningTool(cfg, { vegOnly }, suggestedPlaces);
  }

  let mapData: ReturnType<typeof executeMapDirectionsTool> | null = null;
  if (asksMap) {
    onEvent({
      type: "status",
      tool: "getParkMapAndDirections",
      label: "Looking up park map pins & CMS directions…",
    });
    await new Promise((r) => setTimeout(r, 100));
    // Try to find a specific place name mentioned in the user message
    const allNames = [
      ...(cfg.dining ?? []).map((d) => d.name),
      ...(cfg.rides ?? []).map((r) => r.title),
      ...(cfg.parkMap?.places ?? []).map((p) => p.name),
    ];
    const matchedName = allNames.find((n) => lower.includes(n.toLowerCase()));
    mapData = executeMapDirectionsTool(
      cfg,
      { placeName: matchedName, category: asksFood ? "dining" : undefined },
      suggestedPlaces,
    );
  }

  if (asksSafety && !asksFood && !asksMap) {
    onEvent({
      type: "status",
      tool: "getSafetyAndGuidelines",
      label: "Checking height rules & park guidelines…",
    });
    await new Promise((r) => setTimeout(r, 80));
    executeGuidelinesTool(cfg);
  }

  if (ridesData && heightCm != null) {
    const kidFriendly = ridesData.rides.slice(0, 6);
    if (kidFriendly.length > 0) {
      const list = kidFriendly
        .map(
          (r) =>
            `• **${r.title}** (${r.category}${r.waitMinutes != null ? ` · ~${r.waitMinutes} min wait` : ""}) — ${r.description}`,
        )
        .join("\n");
      sections.push(
        `\n**Great rides for a ${heightCm} cm visitor** (${ridesData.matchingCount} matching attractions currently operating):\n${list}`,
      );
    }
  }

  if (asksPlan) {
    const picks = (ridesData?.rides ?? []).slice(0, 4);
    const wave = scheduleData?.wavePoolAndRainDance?.[0];
    const nextShow = scheduleData?.events?.[0];
    const topFood = (cfg.dining ?? [])[0];
    const slotCount = hours ?? 3;
    const planLines: string[] = [];
    if (picks[0]) {
      planLines.push(
        `• **Hour 1 — Quick Start:** Head straight to **${picks[0].title}**${picks[0].waitMinutes != null ? ` (${picks[0].waitMinutes} min wait)` : ""}${picks[1] ? ` followed by **${picks[1].title}**` : ""}.`,
      );
    }
    if (slotCount >= 2) {
      if (wave) {
        planLines.push(
          `• **Hour 2 — Splash & Cool Down:** Catch **${wave.title}** (${wave.sessions.slice(0, 2).join(", ") || "open sessions"})${picks[2] ? ` and enjoy **${picks[2].title}**` : ""}.`,
        );
      } else if (picks[2]) {
        planLines.push(`• **Hour 2 — Midday Fun:** Enjoy **${picks[2].title}** while lines stay steady.`);
      }
    }
    if (slotCount >= 3) {
      planLines.push(
        `• **Hour 3 — Refuel & Showtime:** Grab a bite at **${topFood?.name ?? "Park View Restaurant"}**${nextShow ? ` and catch **${nextShow.title}** at ${nextShow.time}` : ""}.`,
      );
    }
    if (planLines.length > 0) {
      sections.push(`\n**Suggested ${slotCount}-Hour Game Plan:**\n${planLines.join("\n")}`);
    }
  } else if (waitData && asksWait && !heightCm) {
    const topWaits = waitData.liveWaitTimes.slice(0, 5);
    if (topWaits.length > 0) {
      sections.push(
        `**Shortest Live Wait Times at ${cfg.name}:**\n` +
          topWaits.map((w) => `• **${w.title}** — **${w.waitMinutes} min** (${w.description})`).join("\n"),
      );
    }
  }

  if (diningData && diningData.diningOutlets.length > 0) {
    const outletsText = diningData.diningOutlets
      .slice(0, 4)
      .map((d) => {
        const sampleDishes = d.dishes.slice(0, 2).map((i) => `${i.name} (${i.price})`).join(", ");
        const dirHint = d.directions ? ` · Directions: ${d.directions}` : "";
        return `• **${d.name}** (${d.cuisine})${sampleDishes ? ` — Try: ${sampleDishes}` : ""}${dirHint}`;
      })
      .join("\n");
    sections.push(`\n**Dining Recommendations:**\n${outletsText}`);
  }

  if (mapData && mapData.places.length > 0) {
    const placesText = mapData.places
      .slice(0, 4)
      .map(
        (p) =>
          `• **${p.name}** (${p.category})${p.directions ? ` — ${p.directions}` : ""}`,
      )
      .join("\n");
    sections.push(
      `\n**Map & Directions:**\n${placesText}\nTap any destination button below to open directions directly on the park map!`,
    );
  }

  if (asksShows && !asksPlan && scheduleData) {
    const waveLines = scheduleData.wavePoolAndRainDance.map(
      (w) => `• **${w.title}** (${w.durationMinutes} min): ${w.sessions.join(", ")}`,
    );
    const eventLines = scheduleData.events.map(
      (e) => `• **${e.title}** at **${e.time}** — ${e.description}`,
    );
    sections.push(
      `**Water Sessions & Shows at ${cfg.name}:**\n${[...waveLines, ...eventLines].join("\n")}`,
    );
  }

  if (sections.length === 0) {
    onEvent({
      type: "status",
      tool: "getParkRidesAndStatus",
      label: "Checking park highlights & operating status…",
    });
    const fallbackRides = executeRidesTool(cfg, {}, suggestedPlaces);
    const top = fallbackRides.rides.slice(0, 4);
    sections.push(
      `Hi! I'm **Chiku**, your **${cfg.name}** buddy! I can check live wait times, filter rides by kid height (like 110 cm), suggest veg/non-veg restaurants, and open map directions.\n\n**Top Picks Right Now:**\n` +
        top
          .map((r) => `• **${r.title}**${r.waitMinutes != null ? ` · ${r.waitMinutes} min wait` : ""} — ${r.description}`)
          .join("\n"),
    );
  }

  await emitChunksSlowly(sections.join("\n").trim(), onEvent);

  if (suggestedPlaces.size > 0) {
    onEvent({ type: "places", items: Array.from(suggestedPlaces.values()).slice(0, 4) });
  }
  onEvent({ type: "done", mode: "smart_tools" });
}

export async function streamWonderlaAssistant(params: {
  parkSlug: string;
  message: string;
  history?: AiChatHistoryItem[];
  onEvent: (event: AiStreamEvent) => void;
}) {
  const cfg = await getPark(params.parkSlug);
  if (!cfg) {
    params.onEvent({
      type: "error",
      message: `Park "${params.parkSlug}" could not be found.`,
    });
    return;
  }

  // If no Gemini API key is configured on the server yet, run our smart
  // tool-calling streaming planner so the experience works seamlessly right away.
  if (!GEMINI_KEY) {
    await runSmartToolFallback(cfg, params.message, params.onEvent);
    return;
  }

  const suggestedPlaces = new Map<string, AiSuggestedPlace>();

  try {
    const ai = getGenkit();

    const getParkRidesAndStatus = ai.defineTool(
      {
        name: "getParkRidesAndStatus",
        description:
          "Fetch Wonderla rides, live wait times, operating/maintenance status, and filter by visitor height in cm or ride category.",
        inputSchema: z.object({
          heightCm: z.number().optional().describe("Visitor or child height in centimeters, e.g. 110"),
          category: z.enum(["all", "kids", "family", "water", "thrill"]).optional(),
          kioskOnly: z.boolean().optional(),
        }),
        outputSchema: z.any(),
      },
      async (input) => {
        params.onEvent({
          type: "status",
          tool: "getParkRidesAndStatus",
          label: input.heightCm
            ? `Checking rides for ${input.heightCm} cm & operating status…`
            : "Checking available attractions & operating status…",
        });
        return executeRidesTool(cfg, input, suggestedPlaces);
      },
    );

    const getLiveWaitTimes = ai.defineTool(
      {
        name: "getLiveWaitTimes",
        description: "Get live ride queue wait times sorted shortest-first.",
        inputSchema: z.object({
          maxWaitMinutes: z.number().optional().describe("Optional maximum wait time in minutes"),
        }),
        outputSchema: z.any(),
      },
      async (input) => {
        params.onEvent({
          type: "status",
          tool: "getLiveWaitTimes",
          label: "Checking live ride wait times…",
        });
        return executeWaitTimesTool(cfg, input, suggestedPlaces);
      },
    );

    const getWaterAndEventSchedule = ai.defineTool(
      {
        name: "getWaterAndEventSchedule",
        description: "Get Wave Pool, Rain Disco session timings, and live shows/parade events.",
        inputSchema: z.object({}),
        outputSchema: z.any(),
      },
      async () => {
        params.onEvent({
          type: "status",
          tool: "getWaterAndEventSchedule",
          label: "Checking Wave Pool & live show schedules…",
        });
        return executeSchedulesTool(cfg, suggestedPlaces);
      },
    );

    const getDiningAndMenus = ai.defineTool(
      {
        name: "getDiningAndMenus",
        description: "Search restaurants, veg/non-veg dishes, prices, and CMS walking directions.",
        inputSchema: z.object({
          vegOnly: z.boolean().optional(),
          query: z.string().optional().describe("Optional cuisine, restaurant name, or dish keyword"),
        }),
        outputSchema: z.any(),
      },
      async (input) => {
        params.onEvent({
          type: "status",
          tool: "getDiningAndMenus",
          label: input.vegOnly
            ? "Finding vegetarian restaurants & menus…"
            : "Checking restaurants, menus & directions…",
        });
        return executeDiningTool(cfg, input, suggestedPlaces);
      },
    );

    const getParkMapAndDirections = ai.defineTool(
      {
        name: "getParkMapAndDirections",
        description:
          "Look up any ride, restaurant, or facility on the park map to return zones and CMS directions.",
        inputSchema: z.object({
          placeName: z.string().optional(),
          category: z.string().optional(),
        }),
        outputSchema: z.any(),
      },
      async (input) => {
        params.onEvent({
          type: "status",
          tool: "getParkMapAndDirections",
          label: input.placeName
            ? `Finding map directions to ${input.placeName}…`
            : "Looking up park map pins & directions…",
        });
        return executeMapDirectionsTool(cfg, input, suggestedPlaces);
      },
    );

    const getSafetyAndGuidelines = ai.defineTool(
      {
        name: "getSafetyAndGuidelines",
        description: "Get park height rules, tickets, locker info, swimwear, and safety advisories.",
        inputSchema: z.object({}),
        outputSchema: z.any(),
      },
      async () => {
        params.onEvent({
          type: "status",
          tool: "getSafetyAndGuidelines",
          label: "Checking ride guidelines & park rules…",
        });
        return executeGuidelinesTool(cfg);
      },
    );

    const historyText = (params.history ?? [])
      .slice(-6)
      .map((h) => `${h.role === "user" ? "Visitor" : "Assistant"}: ${h.text}`)
      .join("\n");

    const prompt = historyText
      ? `Conversation so far:\n${historyText}\n\nLatest visitor question: ${params.message}`
      : params.message;

    const { stream, response } = ai.generateStream({
      model: googleAI.model("gemini-2.5-flash"),
      system: `You are Chiku, Wonderla's friendly, energetic mascot & park guide for ${cfg.name} (${cfg.location}).
Rules:
1. NEVER fabricate rides, restaurants, prices, wait times, directions, or timings. Always call ONLY the specific tools needed to read the latest live CMS park data for the visitor's question.
2. When planning an itinerary or answering height questions (e.g., 110 cm child), check ride eligibility, live wait times, and show/wave pool times cleanly, then present a warm, scannable plan with bold headings and short bullet points.
3. If the visitor asks for directions or a restaurant/ride location, call getParkMapAndDirections or getDiningAndMenus and mention that they can tap the map direction button below.
4. Keep responses concise, friendly, and genuinely helpful for a theme park visitor on mobile.`,
      prompt,
      tools: [
        getParkRidesAndStatus,
        getLiveWaitTimes,
        getWaterAndEventSchedule,
        getDiningAndMenus,
        getParkMapAndDirections,
        getSafetyAndGuidelines,
      ],
      maxTurns: 5,
    });

    let emittedAnyText = false;
    for await (const chunk of stream) {
      if (chunk.text) {
        emittedAnyText = true;
        params.onEvent({ type: "chunk", text: chunk.text });
      }
    }

    const finalResponse = await response;
    if (!emittedAnyText && finalResponse.text) {
      params.onEvent({ type: "chunk", text: finalResponse.text });
    }

    if (suggestedPlaces.size > 0) {
      params.onEvent({
        type: "places",
        items: Array.from(suggestedPlaces.values()).slice(0, 4),
      });
    }
    params.onEvent({ type: "done", mode: "genkit" });
  } catch (err) {
    console.error("[wonderla-ai] Genkit error, falling back to smart tools:", err);
    await runSmartToolFallback(cfg, params.message, params.onEvent);
  }
}
