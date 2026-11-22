# Wonderla park API

The Next.js project provides the park data, authentication, and upload APIs for
the Flutter app. The former Next.js QR guest and admin pages have been removed;
the Flutter app is the only user interface.

## Routes

| Route                    | What it is                                              |
|--------------------------|---------------------------------------------------------|
| `/`                      | Redirects to `FLUTTER_WEB_ORIGIN` when configured       |
| `/qr-code/api/...`       | Park data, login, users, settings, and upload APIs       |

Use the Flutter frontend for visitor and admin workflows. QR guest pages are
not served by this backend.

Deploy this folder as its own Vercel project with Root Directory `backend` and
the Next.js framework preset. Set `FLUTTER_WEB_ORIGIN` to the exact HTTPS origin
of the Flutter project. The park-list endpoint is `GET /qr-code/api/parks`.

## Seeded parks

On first run the store seeds 5 parks: `bengaluru`, `kochi`, `hyderabad`,
`bhubaneswar`, `chennai`. Add more from the admin panel (slug is derived from
the name, e.g. "Wonderla Pune" → `pune`).

## Data storage

Each park is one JSON file under `data/qr-code/parks/<slug>.json`
(configurable via `QR_DATA_DIR`). No database required. Swapping to a real DB
later only means reimplementing `_lib/store.ts`.

> Decide whether to commit `data/qr-code/` or gitignore it. Committing gives
> you versioned content; ignoring keeps prod content out of the repo.

## Users & roles

Two roles, managed in the Flutter app:

- **superadmin** — full access: edit any park, add/delete parks, toggle a
  park active/inactive, and create/delete users (Admin → **Users** tab).
- **park** — scoped to ONE park. Can edit only that park's content
  (rides, events, menu, wait times, etc.). Cannot add/delete parks, cannot
  change the active flag, and has no Users tab.

**Creating park-level users:** sign in as superadmin in the Flutter app, open
the **Users** tab, then add a park user and assign a park. That user signs in
through the Flutter app and sees only their park's editor.

Users live in `data/qr-code/users.json`; passwords are salted + scrypt-hashed
(never stored in plaintext). On first run a single superadmin is seeded from
`QR_ADMIN_USERNAME` / `QR_ADMIN_PASSWORD`. Those env credentials also act as a
permanent bootstrap superadmin, so you can never lock yourself out even if
`users.json` is lost.

Login sets an HMAC-signed, httpOnly session cookie (8h) that carries the
user's identity + role + park, so the API enforces per-park access. Reads are
public; all writes require a valid session with the right role.

## API (under `/qr-code/api`)

| Method | Path                     | Auth  | Purpose                 |
|--------|--------------------------|-------|-------------------------|
| POST   | `/auth/login`            | —     | Sign in                 |
| POST   | `/auth/logout`           | —     | Sign out                |
| GET    | `/auth/session`          | —     | Is the caller signed in |
| GET    | `/parks`                 | —     | List park summaries     |
| POST   | `/parks`                 | super | Create a park           |
| GET    | `/parks/<slug>`          | —     | Full config for a park  |
| PUT    | `/parks/<slug>`          | owner | Replace a park's config |
| DELETE | `/parks/<slug>`          | super | Delete a park           |
| GET    | `/users`                 | super | List users              |
| POST   | `/users`                 | super | Create a user           |
| DELETE | `/users/<username>`      | super | Delete a user           |
| POST   | `/ai/chat`               | —     | Ask Chiku Genkit stream |

Auth levels: **—** public · **owner** = superadmin or the park's own user ·
**super** = superadmin only. (`PUT /parks/<slug>` is **owner**.)

## Config shape

See `_lib/types.ts`. Each park has: `rides`, `events`, `liveWaitTimes`,
`waveRainDance`, `safetyHygiene`, `maintenanceLog`, `parkMap`, `dining`,
`rideGuidelines`, plus `name` / `location` / `active`.

## Notes

- All endpoints under `app/` are pure TypeScript Next.js Route Handlers (no React UI files).
- Set `GEMINI_API_KEY` in Vercel Environment Variables to enable live Gemini 2.5 Flash tool calling for Ask Chiku (otherwise the smart park-tools streaming fallback runs automatically).
- Connect a private Vercel Blob store (`BLOB_READ_WRITE_TOKEN` / `BLOB_STORE_ID`) so CMS edits and uploads persist in production.
