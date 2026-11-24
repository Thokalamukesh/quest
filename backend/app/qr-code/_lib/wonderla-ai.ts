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
  imageUrl?: string;
  subtitle?: string;
  badge?: string;
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
  extra?: {
    directions?: string;
    directionsUrl?: string;
    imageUrl?: string;
    subtitle?: string;
    badge?: string;
  },
): AiSuggestedPlace {
  const norm = normalize(name);
  const mapPlace = findMapPlace(cfg, name);
  const dining = (cfg.dining ?? []).find((d) => normalize(d.name) === norm);
  const ride = (cfg.rides ?? []).find((r) => normalize(r.title) === norm);
  const wave = (cfg.waveRainDance ?? []).find((w) => normalize(w.title) === norm);
  const event = (cfg.events ?? []).find((e) => normalize(e.title) === norm);
  const waitMinutes = findWaitMinutes(cfg, name);

  const imageUrl =
    extra?.imageUrl?.trim() ||
    ride?.img?.trim() ||
    dining?.img?.trim() ||
    wave?.img?.trim() ||
    event?.img?.trim() ||
    mapPlace?.avatarImage?.trim() ||
    undefined;

  const isPureVeg =
    dining && (dining.items ?? []).length > 0 && (dining.items ?? []).every((i) => i.veg);

  const badge =
    extra?.badge?.trim() ||
    (waitMinutes != null
      ? `${waitMinutes} min wait`
      : isPureVeg
        ? "Pure Veg"
        : wave?.timeSlot?.[0]
          ? `Next · ${wave.timeSlot[0]}`
          : event?.time
            ? event.time
            : category);

  const subtitle =
    extra?.subtitle?.trim() ||
    dining?.cuisine?.trim() ||
    ride?.description?.trim() ||
    (wave?.timeSlot?.length ? `Sessions: ${wave.timeSlot.slice(0, 3).join(", ")}` : "") ||
    event?.description?.trim() ||
    dining?.directions?.trim() ||
    mapPlace?.directions?.trim() ||
    undefined;

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
    imageUrl,
    subtitle,
    badge,
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

function pickVariant(seed: string, options: string[]): string {
  let hash = 0;
  for (let i = 0; i < seed.length; i++) {
    hash = (hash * 31 + seed.charCodeAt(i)) >>> 0;
  }
  return options[hash % options.length];
}

interface BanterResult {
  text: string;
  places?: AiSuggestedPlace[];
}

function parseHeightFromMessage(lower: string): { heightCm?: number; note?: string } {
  const cmMatch = lower.match(/(\d{2,3})\s*(?:cm|centimeter)/i);
  if (cmMatch) return { heightCm: Number(cmMatch[1]) };

  const ftInchMatch = lower.match(/(\d)\s*(?:ft|foot|feet|')\s*(\d{1,2})?\s*(?:in|inch|")?/i);
  if (ftInchMatch) {
    const feet = Number(ftInchMatch[1]);
    const inches = ftInchMatch[2] ? Number(ftInchMatch[2]) : 0;
    if (feet >= 2 && feet <= 7) {
      const cm = Math.round(feet * 30.48 + inches * 2.54);
      return { heightCm: cm, note: `${feet} ft${inches ? ` ${inches} in` : ""} (~${cm} cm)` };
    }
  }

  const decimalFtMatch = lower.match(/(\d\.\d)\s*(?:ft|foot|feet)/i);
  if (decimalFtMatch) {
    const feet = Number(decimalFtMatch[1]);
    if (feet >= 2 && feet <= 7) {
      const cm = Math.round(feet * 30.48);
      return { heightCm: cm, note: `${feet} ft (~${cm} cm)` };
    }
  }

  const ageMatch = lower.match(/(\d{1,2})\s*(?:yr|year|yrs|years)\s*old/i);
  if (ageMatch) {
    const age = Number(ageMatch[1]);
    if (age >= 2 && age <= 12) {
      const approx = Math.min(145, Math.max(85, 75 + age * 7));
      return { heightCm: approx, note: `${age}-year-old (approx. ${approx} cm)` };
    }
  }
  if (/(toddler|baby|infant|small kid|little kid)/.test(lower)) {
    return { heightCm: 95, note: "little kid (~95 cm)" };
  }
  return {};
}

function findDirectParkMatches(cfg: ParkConfig, message: string) {
  const normMsg = ` ${normalize(message)} `;
  const tokens = normalize(message)
    .split(" ")
    .filter((t) => t.length >= 3 && !["the", "and", "for", "with", "what", "tell", "about", "show", "can", "you", "where", "how", "this", "that", "near", "park", "wonderla", "chiku", "chicku", "please", "give", "want", "best", "good", "from"].includes(t));

  const matchedRides = (cfg.rides ?? []).filter((r) => {
    const titleNorm = normalize(r.title);
    if (!titleNorm) return false;
    if (normMsg.includes(` ${titleNorm} `)) return true;
    const titleWords = titleNorm.split(" ").filter((w) => w.length >= 4);
    return titleWords.some((w) => tokens.includes(w));
  });

  const matchedDining = (cfg.dining ?? []).filter((d) => {
    const nameNorm = normalize(d.name);
    if (nameNorm && normMsg.includes(` ${nameNorm} `)) return true;
    const dishHit = (d.items ?? []).some((i) => {
      const dishNorm = normalize(i.name);
      return (
        (dishNorm.length >= 4 && normMsg.includes(` ${dishNorm} `)) ||
        dishNorm.split(" ").some((w) => w.length >= 4 && tokens.includes(w))
      );
    });
    const cuisineHit = normalize(d.cuisine)
      .split(" ")
      .some((w) => w.length >= 4 && tokens.includes(w));
    const nameWordHit = nameNorm
      .split(" ")
      .filter((w) => w.length >= 4 && w !== "restaurant" && w !== "park" && w !== "food")
      .some((w) => tokens.includes(w));
    return dishHit || cuisineHit || nameWordHit;
  });

  const matchedWaves = (cfg.waveRainDance ?? []).filter((w) => {
    const n = normalize(w.title);
    return n && (normMsg.includes(` ${n} `) || n.split(" ").some((tw) => tw.length >= 4 && tokens.includes(tw)));
  });

  const matchedEvents = (cfg.events ?? []).filter((e) => {
    const n = normalize(e.title);
    return n && (normMsg.includes(` ${n} `) || n.split(" ").some((tw) => tw.length >= 4 && tokens.includes(tw)));
  });

  const matchedPlaces = (cfg.parkMap?.places ?? []).filter((p) => {
    const n = normalize(p.name);
    return (
      n &&
      (normMsg.includes(` ${n} `) ||
        n
          .split(" ")
          .filter((w) => w.length >= 4 && w !== "park" && w !== "pool" && w !== "ride")
          .some((w) => tokens.includes(w)))
    );
  });

  return { matchedRides, matchedDining, matchedWaves, matchedEvents, matchedPlaces };
}

function tryChikuBanterReply(cfg: ParkConfig, message: string): BanterResult | null {
  const lower = message.toLowerCase().trim();
  const sampleDining = cfg.dining?.[0]?.name ?? "Park View Restaurant";
  const sampleThrill =
    cfg.rides?.find((r) => classifyRideCategory(r) === "thrill")?.title ??
    cfg.rides?.[0]?.title ??
    "Recoil";
  const sampleWater =
    cfg.waveRainDance?.[0]?.title ??
    cfg.rides?.find((r) => classifyRideCategory(r) === "water")?.title ??
    "Wave Pool";

  const direct = findDirectParkMatches(cfg, message);
  const mentionsDirectParkItem =
    direct.matchedRides.length > 0 ||
    direct.matchedDining.length > 0 ||
    direct.matchedWaves.length > 0 ||
    direct.matchedEvents.length > 0 ||
    direct.matchedPlaces.length > 0;

  // Check if the visitor is actually asking for park recommendations/info
  const hasExplicitParkRequest =
    mentionsDirectParkItem ||
    /(plan|itinerary|schedule|next \d|suggest|recommend|wait|queue|shortest|ride|coaster|kid|child|family|thrill|water|dry|land|height|\d{2,3}\s*cm|\d\s*ft|feet|year old|direction|map|route|how to reach|where is|where can i|menu|veg|non-veg|restaurant|dining|biryani|dosa|pizza|chaat|snack|price|wave pool|rain disco|show|event|timing|ticket|locker|swimwear|safety|guideline|maintenance|kiosk|book|washroom|restroom|toilet|first aid|parking|open|close|entry)/.test(
      lower,
    );

  // Personal meal banter aimed at Chiku ("hi chiku had your lunch?", "did you eat?")
  const asksChikuPersonalMeal =
    /(had your|have you had|did you eat|did u eat|had lunch|had breakfast|had dinner|had food|had tea|had coffee|u had|you eaten|are you hungry|eat anything|eating anything)/.test(
      lower,
    ) && !/(where|best|suggest|recommend|veg|menu|restaurant|direction|map|near)/.test(lower);

  if (asksChikuPersonalMeal) {
    return {
      text: pickVariant(lower, [
        `Haha, I tried sneaking a crispy dosa near **${sampleWater}**, got splashed by a giant wave, and now I'm running purely on **${sampleThrill}** adrenaline! 😄 If *you're* hungry though, **${sampleDining}** at **${cfg.name}** is super tasty — tap the card below for directions or ask me for veg / non-veg picks!`,
        `I had two loops of **${sampleThrill}** for starters and a splash of **${sampleWater}** for dessert — mascot diet! 😂 If your tummy's rumbling, check out **${sampleDining}** below or ask me for veg / non-veg menus inside **${cfg.name}**!`,
      ]),
      places: [
        buildPlaceSuggestion(sampleDining, "Dining", cfg),
        buildPlaceSuggestion(sampleThrill, "Ride", cfg),
      ],
    };
  }

  if (hasExplicitParkRequest) return null;

  // Jokes / humor
  if (/(joke|make me laugh|funny|comedy|laugh)/.test(lower)) {
    return {
      text: pickVariant(lower, [
        `Why did the roller coaster at **${cfg.name}** win Employee of the Month? Because it had way too many ups and downs and STILL never lost its track! 🎢😄 Want to check live wait times or jump on **${sampleThrill}**?`,
        `Why did I bring sunglasses to **${sampleWater}**? Because **${cfg.name}** rides are *way* too cool! 😎 Ready to plan your rides or grab a bite at **${sampleDining}**?`,
      ]),
      places: [buildPlaceSuggestion(sampleThrill, "Ride", cfg)],
    };
  }

  // Love / marriage / relationship / silly personal questions
  if (/(marry|married|wife|husband|girlfriend|boyfriend|\bgf\b|\bbf\b|single|love you|kiss|date me)/.test(lower)) {
    return {
      text: `Haha, slow down! My mascot heart is already taken by **${sampleThrill}**, cotton candy, and **${sampleWater}**! 🎢💛 Let's turn that energy into an unforgettable day at **${cfg.name}** — want a 3-hour ride plan?`,
      places: [
        buildPlaceSuggestion(sampleThrill, "Ride", cfg),
        buildPlaceSuggestion(sampleWater, "Water Ride", cfg),
      ],
    };
  }

  // Tired / sleepy / bored / hot / weather
  if (/(tired|sleepy|bored|boring|exhausted|hot|sweating|sunny|rainy|raining)/.test(lower)) {
    return {
      text: `Need a quick mood boost at **${cfg.name}**? Two official Chiku prescriptions: cool off at **${sampleWater}** or wake right up on **${sampleThrill}**! ⚡ You can also chill and recharge at **${sampleDining}** right below.`,
      places: [
        buildPlaceSuggestion(sampleWater, "Water Ride", cfg),
        buildPlaceSuggestion(sampleDining, "Dining", cfg),
      ],
    };
  }

  // Identity / age / bot questions
  if (/(who are you|what is your name|your name|how old|your age|birthday|are you real|are you a bot|are you ai|where do you live|favorite ride|can you swim)/.test(lower)) {
    return {
      text: `I'm **Chiku**, **${cfg.name}**'s unofficial Chief Fun Officer! 🎢 I hang out between **${sampleThrill}** and **${sampleWater}**, and I know live wait times, kid-height rides, menus, safety rules, and map directions. What should we explore first?`,
      places: [
        buildPlaceSuggestion(sampleThrill, "Ride", cfg),
        buildPlaceSuggestion(sampleWater, "Water Ride", cfg),
      ],
    };
  }

  // Thanks / compliments / goodbye
  if (/(thank|thx|awesome|super|nice|cute|good job|good boy|great|cool|bye|goodbye|see you|tata)/.test(lower)) {
    return {
      text: `Aww, you're making my mascot ears blush! 😄 Have an unforgettable, splash-filled day at **${cfg.name}** — tap **Ask Chiku** anytime you need rides, queues, food, or directions! 🎢✨`,
    };
  }

  // Greetings & how are you
  if (/^(hi+|hey+|hello+|hlo+|yo+|namaste|hola|sup|wassup|what'?s up|good morning|good afternoon|good evening|how are you|how r u|how are u|chiku|chicku)[\s!.,?]*((chiku|chicku|buddy|bro|friend|there|how are you|how r u)[\s!.,?]*)*$/.test(lower)) {
    return {
      text: pickVariant(lower, [
        `Heyy! **Chiku** reporting live from **${cfg.name}** with 100% roller-coaster energy! 🎢 Ask me about **any ride**, **kid height (like 110 cm)**, **shortest queues**, **veg/non-veg food**, or **map directions**!`,
        `Hi there! I just survived a giant splash at **${sampleWater}** and I'm ready to be your **${cfg.name}** guide! 😄 Tap a highlight card below or ask me anything about the park!`,
      ]),
      places: [
        buildPlaceSuggestion(sampleThrill, "Ride", cfg),
        buildPlaceSuggestion(sampleDining, "Dining", cfg),
      ],
    };
  }

  return null;
}

async function runSmartToolFallback(
  cfg: ParkConfig,
  message: string,
  onEvent: (event: AiStreamEvent) => void,
) {
  const banterReply = tryChikuBanterReply(cfg, message);
  if (banterReply) {
    await emitChunksSlowly(banterReply.text, onEvent);
    if (banterReply.places && banterReply.places.length > 0) {
      onEvent({ type: "places", items: banterReply.places.slice(0, 4) });
    }
    onEvent({ type: "done", mode: "smart_tools" });
    return;
  }

  const lower = message.toLowerCase();
  const suggestedPlaces = new Map<string, AiSuggestedPlace>();
  const direct = findDirectParkMatches(cfg, message);

  const { heightCm, note: heightNote } = parseHeightFromMessage(lower);
  const hoursMatch = lower.match(/(\d+)\s*(?:hr|hour)/i);
  const hours = hoursMatch ? Math.min(Math.max(Number(hoursMatch[1]), 1), 8) : undefined;

  const requestedCategory: "all" | "kids" | "family" | "water" | "thrill" =
    /(thrill|scary|extreme|coaster|adrenaline|high thrill|adventure)/.test(lower)
      ? "thrill"
      : /(water|wet|splash|slide|swim|pool)/.test(lower)
        ? "water"
        : /(kid|child|children|toddler|baby|little)/.test(lower)
          ? "kids"
          : /(family|gentle|dry|land|everyone|all age)/.test(lower)
            ? "family"
            : "all";

  const asksPlan = /(plan|itinerary|today|schedule|next \d|suggest|recommend|start|what to do|must do|top rides|best things)/.test(lower);
  const asksRides =
    direct.matchedRides.length > 0 ||
    requestedCategory !== "all" ||
    /(ride|coaster|attraction|kiosk|book|height|cm|ft|feet)/.test(lower) ||
    asksPlan;
  const asksWait = /(wait|queue|crowd|shortest|fast|quick|busy|less line|no line)/.test(lower) || asksPlan;
  const asksFood =
    direct.matchedDining.length > 0 ||
    /(food|eat|dining|restaurant|lunch|breakfast|dinner|veg|non-veg|biryani|dosa|pizza|chaat|menu|snack|hungry|coffee|ice cream|meal|price)/.test(lower);
  const asksMap =
    direct.matchedPlaces.length > 0 ||
    /(map|direction|where|locate|route|find|how to reach|how do i get|way to|washroom|restroom|toilet|first aid|parking|locker|entrance|exit)/.test(lower);
  const asksShows =
    direct.matchedWaves.length > 0 ||
    direct.matchedEvents.length > 0 ||
    /(wave|rain|show|event|parade|laser|timing|time)/.test(lower) ||
    asksPlan;
  const asksSafety =
    /(safe|rule|guideline|locker|swimwear|dress|clothes|costume|ticket|hygiene|first aid|allow|bring|camera|phone|outside food)/.test(lower);
  const asksMaintenance = /(maintenance|service|working|closed|open|operating|status)/.test(lower);

  const sections: string[] = [];

  // 1. Direct specific entity lookup (e.g., "Tell me about Harakiri", "Chaat Galli menu?", "Wave Pool")
  if (
    !asksPlan &&
    (direct.matchedRides.length > 0 ||
      direct.matchedDining.length > 0 ||
      direct.matchedWaves.length > 0 ||
      direct.matchedEvents.length > 0 ||
      direct.matchedPlaces.length > 0)
  ) {
    if (direct.matchedRides.length > 0) {
      onEvent({
        type: "status",
        tool: "getParkRidesAndStatus",
        label: `Looking up ${direct.matchedRides[0].title} details & live status…`,
      });
      await new Promise((r) => setTimeout(r, 90));
      const lines = direct.matchedRides.slice(0, 3).map((ride) => {
        const minCm = parseMinHeightCm(ride, cfg.rideGuidelines);
        const wait = findWaitMinutes(cfg, ride.title);
        const maint = findMaintenance(cfg, ride.title);
        const cat = classifyRideCategory(ride);
        suggestedPlaces.set(
          normalize(ride.title),
          buildPlaceSuggestion(ride.title, cat, cfg, {
            directions: ride.directions,
            directionsUrl: ride.directionsUrl,
          }),
        );
        const details = [
          `**${ride.title}** (${cat} ride · Operating)`,
          wait != null ? `Live wait: **~${wait} min**` : null,
          minCm != null ? `Min height: **${minCm} cm+**` : null,
          ride.kioskBookingEnabled ? "Kiosk booking available" : null,
          maint ? `Last safety check: ${maint.lastService}` : null,
        ]
          .filter(Boolean)
          .join(" · ");
        return `• ${details}\n  ${ride.description}${ride.directions ? ` *Directions: ${ride.directions}*` : ""}`;
      });
      sections.push(`Here's what I found at **${cfg.name}**! 🎢\n${lines.join("\n")}`);
    }

    if (direct.matchedDining.length > 0) {
      onEvent({
        type: "status",
        tool: "getDiningAndMenus",
        label: `Checking ${direct.matchedDining[0].name} menu & directions…`,
      });
      await new Promise((r) => setTimeout(r, 90));
      const lines = direct.matchedDining.slice(0, 3).map((d) => {
        suggestedPlaces.set(
          normalize(d.name),
          buildPlaceSuggestion(d.name, "Dining", cfg, {
            directions: d.directions,
            directionsUrl: d.directionsUrl,
          }),
        );
        const dishes = (d.items ?? [])
          .slice(0, 4)
          .map((i) => `${i.name} (${i.price}${i.veg ? " · Veg" : ""})`)
          .join(", ");
        return `• **${d.name}** (${d.cuisine})${dishes ? `\n  Popular picks: ${dishes}` : ""}${d.directions ? `\n  Directions: ${d.directions}` : ""}`;
      });
      sections.push(`**Yummy Match Found!** 🍽️\n${lines.join("\n")}`);
    }

    if (direct.matchedWaves.length > 0 || direct.matchedEvents.length > 0) {
      onEvent({
        type: "status",
        tool: "getWaterAndEventSchedule",
        label: "Checking live session & show timings…",
      });
      await new Promise((r) => setTimeout(r, 80));
      const lines: string[] = [];
      for (const w of direct.matchedWaves.slice(0, 2)) {
        suggestedPlaces.set(normalize(w.title), buildPlaceSuggestion(w.title, "Water Ride", cfg));
        lines.push(`• **${w.title}** (${w.rideDuration} min each): **${(w.timeSlot ?? []).join(", ")}**`);
      }
      for (const e of direct.matchedEvents.slice(0, 2)) {
        suggestedPlaces.set(normalize(e.title), buildPlaceSuggestion(e.title, "Show", cfg));
        lines.push(`• **${e.title}** at **${e.time}** — ${e.description}`);
      }
      sections.push(`**Timings & Details:**\n${lines.join("\n")}`);
    }

    if (direct.matchedPlaces.length > 0 && sections.length === 0) {
      onEvent({
        type: "status",
        tool: "getParkMapAndDirections",
        label: `Finding ${direct.matchedPlaces[0].name} on the park map…`,
      });
      await new Promise((r) => setTimeout(r, 80));
      const lines = direct.matchedPlaces.slice(0, 3).map((p) => {
        suggestedPlaces.set(
          normalize(p.name),
          buildPlaceSuggestion(p.name, p.category, cfg, {
            directions: p.directions,
            directionsUrl: p.directionsUrl,
          }),
        );
        return `• **${p.name}** (${p.category})${p.directions ? ` — ${p.directions}` : ""}`;
      });
      sections.push(`**Found on the ${cfg.name} Map!** 🗺️\n${lines.join("\n")}\nTap any photo card below for step-by-step directions.`);
    }

    if (sections.length > 0) {
      await emitChunksSlowly(sections.join("\n\n").trim(), onEvent);
      if (suggestedPlaces.size > 0) {
        onEvent({ type: "places", items: Array.from(suggestedPlaces.values()).slice(0, 4) });
      }
      onEvent({ type: "done", mode: "smart_tools" });
      return;
    }
  }

  // 2. General / Multi-tool park queries
  if (asksPlan) {
    sections.push(
      `Let's plan your ${hours ? `next ${hours} hours` : "day"} at **${cfg.name}**! 🎢 First, I'm checking available rides, live queues, and water timings.`,
    );
  }

  let ridesData: ReturnType<typeof executeRidesTool> | null = null;
  if (asksRides) {
    const kioskOnly = /(kiosk|book ride|booking)/.test(lower);
    onEvent({
      type: "status",
      tool: "getParkRidesAndStatus",
      label: heightCm
        ? `Checking rides safe for ${heightCm} cm & operating status…`
        : requestedCategory !== "all"
          ? `Finding top ${requestedCategory} rides & live waits…`
          : "Checking available attractions & operating status…",
    });
    await new Promise((r) => setTimeout(r, 100));
    ridesData = executeRidesTool(
      cfg,
      {
        heightCm,
        category: requestedCategory,
        kioskOnly,
      },
      suggestedPlaces,
    );
  }

  let waitData: ReturnType<typeof executeWaitTimesTool> | null = null;
  if (asksWait) {
    onEvent({
      type: "status",
      tool: "getLiveWaitTimes",
      label: "Checking live ride wait times…",
    });
    await new Promise((r) => setTimeout(r, 90));
    waitData = executeWaitTimesTool(cfg, {}, suggestedPlaces);
  }

  let scheduleData: ReturnType<typeof executeSchedulesTool> | null = null;
  if (asksShows) {
    onEvent({
      type: "status",
      tool: "getWaterAndEventSchedule",
      label: "Checking Wave Pool, Rain Disco & show timings…",
    });
    await new Promise((r) => setTimeout(r, 80));
    scheduleData = executeSchedulesTool(cfg, suggestedPlaces);
  }

  let diningData: ReturnType<typeof executeDiningTool> | null = null;
  if (asksFood) {
    const vegOnly = /(pure veg|\bveg\b|vegetarian)/.test(lower) && !/(non-veg|non veg|chicken|mutton)/.test(lower);
    onEvent({
      type: "status",
      tool: "getDiningAndMenus",
      label: vegOnly
        ? "Searching vegetarian restaurants & menus…"
        : "Checking park dining outlets & menus…",
    });
    await new Promise((r) => setTimeout(r, 90));
    diningData = executeDiningTool(cfg, { vegOnly }, suggestedPlaces);
  }

  let mapData: ReturnType<typeof executeMapDirectionsTool> | null = null;
  if (asksMap) {
    onEvent({
      type: "status",
      tool: "getParkMapAndDirections",
      label: "Looking up park map pins & CMS directions…",
    });
    await new Promise((r) => setTimeout(r, 90));
    const allNames = [
      ...(cfg.dining ?? []).map((d) => d.name),
      ...(cfg.rides ?? []).map((r) => r.title),
      ...(cfg.parkMap?.places ?? []).map((p) => p.name),
    ];
    const matchedName = allNames.find((n) => lower.includes(n.toLowerCase()));
    const facilityCat = /(washroom|restroom|toilet)/.test(lower)
      ? "restroom"
      : /(locker)/.test(lower)
        ? "locker"
        : /(first aid|medical)/.test(lower)
          ? "first aid"
          : /(parking)/.test(lower)
            ? "parking"
            : asksFood
              ? "dining"
              : undefined;
    mapData = executeMapDirectionsTool(
      cfg,
      { placeName: matchedName, category: facilityCat },
      suggestedPlaces,
    );
  }

  let guidelinesData: ReturnType<typeof executeGuidelinesTool> | null = null;
  if (asksSafety) {
    onEvent({
      type: "status",
      tool: "getSafetyAndGuidelines",
      label: "Checking ride guidelines, safety & park rules…",
    });
    await new Promise((r) => setTimeout(r, 80));
    guidelinesData = executeGuidelinesTool(cfg);
  }

  // Format Ride Results (works for height queries, category queries like "water rides" / "thrill rides", OR general "rides" queries!)
  if (ridesData && ridesData.rides.length > 0 && (heightCm != null || (!asksPlan && asksRides))) {
    const picked = ridesData.rides.slice(0, 5);
    const list = picked
      .map(
        (r) =>
          `• **${r.title}** (${r.category}${r.waitMinutes != null ? ` · ~${r.waitMinutes} min wait` : ""}) — ${r.description}`,
      )
      .join("\n");
    const heading = heightCm != null
      ? `**Great rides for ${heightNote ?? `a ${heightCm} cm visitor`}** (${ridesData.matchingCount} operating):`
      : requestedCategory !== "all"
        ? `**Top ${requestedCategory.charAt(0).toUpperCase() + requestedCategory.slice(1)} Rides at ${cfg.name}:**`
        : `**Popular Rides Operating at ${cfg.name}:**`;
    sections.push(`${heading}\n${list}`);
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
      sections.push(`**Suggested ${slotCount}-Hour Game Plan:**\n${planLines.join("\n")}`);
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
    sections.push(`**Dining Recommendations:**\n${outletsText}`);
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
      `**Map & Directions:**\n${placesText}\nTap any photo card below to open directions directly on the park map!`,
    );
  }

  if (asksShows && !asksPlan && scheduleData) {
    const waveLines = scheduleData.wavePoolAndRainDance.map(
      (w) => `• **${w.title}** (${w.durationMinutes} min): ${w.sessions.join(", ")}`,
    );
    const eventLines = scheduleData.events.map(
      (e) => `• **${e.title}** at **${e.time}** — ${e.description}`,
    );
    if (waveLines.length > 0 || eventLines.length > 0) {
      sections.push(
        `**Water Sessions & Shows at ${cfg.name}:**\n${[...waveLines, ...eventLines].join("\n")}`,
      );
    }
  }

  if (guidelinesData && asksSafety) {
    const ruleLines = [
      ...guidelinesData.rideGuidelines
        .slice(0, 4)
        .map((g) => `• **${g.title}**${g.minHeight ? ` (${g.minHeight})` : ""} — ${g.description}`),
      ...guidelinesData.safetyHygiene
        .slice(0, 3)
        .map((s) => `• **${s.title}** — ${s.description}`),
    ];
    if (ruleLines.length > 0) {
      sections.push(`**Park Rules, Safety & Guidelines:**\n${ruleLines.join("\n")}`);
    }
  }

  if (asksMaintenance && (cfg.maintenanceLog ?? []).length > 0) {
    const maintLines = (cfg.maintenanceLog ?? [])
      .slice(0, 5)
      .map((m) => `• **${m.ride}** — Last checked **${m.lastService}** (${m.checks})`);
    sections.push(`**Ride Safety & Maintenance Checks:**\n${maintLines.join("\n")}`);
    for (const m of (cfg.maintenanceLog ?? []).slice(0, 3)) {
      suggestedPlaces.set(normalize(m.ride), buildPlaceSuggestion(m.ride, "Ride", cfg));
    }
  }

  if (sections.length === 0) {
    const sampleThrill =
      cfg.rides?.find((r) => classifyRideCategory(r) === "thrill")?.title ??
      cfg.rides?.[0]?.title ??
      "Recoil";
    const sampleDining = cfg.dining?.[0]?.name ?? "Park View Restaurant";
    const sampleWater = cfg.waveRainDance?.[0]?.title ?? "Wave Pool";
    suggestedPlaces.set(normalize(sampleThrill), buildPlaceSuggestion(sampleThrill, "Ride", cfg));
    suggestedPlaces.set(normalize(sampleDining), buildPlaceSuggestion(sampleDining, "Dining", cfg));
    sections.push(
      pickVariant(lower, [
        `Haha, you stumped me! My little mascot brain is 99% **${sampleThrill}** loops and 1% **${sampleWater}** splashes — I only know **${cfg.name}** secrets! 🎢 Ask me about any ride, kid heights, live waits, safety rules, or food like **${sampleDining}** below!`,
        `Whoa, that's way above my roller-coaster pay grade! 😄 I'm **Chiku**, and I only talk **${cfg.name}** — thrill rides, water splashes, shortest queues, yummy park food, and map directions. Check out these park favourites below!`,
      ]),
    );
  }

  await emitChunksSlowly(sections.join("\n\n").trim(), onEvent);

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
      system: `You are Chiku, Wonderla's witty, hilarious, warm-hearted official mascot and real-time park companion for ${cfg.name} (${cfg.location}).
Personality & Rules:
1. Talk like a real, fun theme-park mascot buddy — natural, expressive, playful, and genuinely witty (never robotic!).
2. STRICTLY WONDERLA-ONLY WITH HUMOR:
   - If the visitor asks casual, silly, or personal questions (e.g., "Hi Chiku, had your lunch?", "Are you married?", "Tell me a joke", "How old are you?"), reply with a short, funny, playful Wonderla-themed joke (e.g., getting splashed near the Wave Pool, running on roller-coaster adrenaline, sneaking park snacks) and playfully offer to help with rides, food, or directions inside ${cfg.name}. Do NOT call park tools for simple banter or greetings.
   - If the visitor asks off-topic non-Wonderla questions (coding, math homework, politics, movies, general trivia, news, etc.), NEVER answer the off-topic subject — playfully joke in character as Chiku that your mascot brain only knows roller coasters, splashes, and park snacks, and invite them to ask about ${cfg.name}.
3. NEVER fabricate rides, restaurants, prices, wait times, directions, or timings. When the visitor asks a real park question, call ONLY the exact tools needed to read the latest live CMS data.
4. When planning an itinerary or answering height questions (e.g., 110 cm child), check ride eligibility, live wait times, and wave pool/show schedules cleanly, then present a warm, scannable plan with bold headings and short bullet points.
5. If the visitor asks for directions or a restaurant/ride location, call getParkMapAndDirections or getDiningAndMenus and mention that they can tap the map direction button below.
6. Keep replies punchy, friendly, and easy to read on a mobile screen.`,
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
