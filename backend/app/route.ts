import { NextResponse } from "next/server";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function resolveRedirectOrigin(): string | null {
  const raw = process.env.FLUTTER_WEB_ORIGIN ?? "";
  const first = raw
    .split(",")
    .map((item) => item.trim())
    .find((item) => /^https?:\/\//i.test(item));
  return first ?? null;
}

const STATUS_HTML = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Wonderla Park API</title>
  <style>
    * { box-sizing: border-box; }
    body {
      margin: 0;
      min-height: 100vh;
      padding: 32px 20px;
      display: flex;
      align-items: center;
      justify-content: center;
      background: linear-gradient(155deg, #0F2357 0%, #1F44A8 100%);
      font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      color: #0F2357;
    }
    .card {
      width: 100%;
      max-width: 520px;
      background: #fff;
      border-radius: 24px;
      padding: 28px 26px;
      box-shadow: 0 24px 60px rgba(9, 20, 56, 0.32);
    }
    .badge {
      display: inline-flex;
      align-items: center;
      gap: 8px;
      padding: 6px 12px;
      border-radius: 999px;
      background: #ECF9F2;
      border: 1px solid #BBE7CF;
      color: #15803D;
      font-size: 12.5px;
      font-weight: 700;
      margin-bottom: 14px;
    }
    .dot {
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: #22C55E;
      display: inline-block;
    }
    h1 { margin: 0 0 8px; font-size: 24px; font-weight: 800; letter-spacing: -0.02em; }
    p.lead { margin: 0 0 20px; font-size: 14.5px; line-height: 1.55; color: #4B5D7C; }
    .endpoints { display: grid; gap: 10px; margin-bottom: 18px; }
    .ep {
      display: flex;
      align-items: center;
      justify-content: space-between;
      padding: 12px 14px;
      border-radius: 14px;
      background: #F4F7FC;
      border: 1px solid #DCE5F5;
      color: #0F2357;
      text-decoration: none;
      font-weight: 700;
      font-size: 13.5px;
    }
    a.ep { color: #1F44A8; }
    .tag-ok { color: #15803D; font-size: 12px; }
    .tag-ai { color: #1F44A8; font-size: 12px; }
    .tip {
      margin: 0;
      padding: 11px 13px;
      border-radius: 12px;
      background: #FFFBEB;
      border: 1px solid #FDE68A;
      color: #78350F;
      font-size: 12.5px;
      line-height: 1.45;
    }
  </style>
</head>
<body>
  <section class="card">
    <div class="badge"><span class="dot"></span>API Server Online</div>
    <h1>Wonderla Visitor &amp; Ask Chiku API</h1>
    <p class="lead">This Node.js API powers the Flutter Visitor App, Admin CMS, park maps, and Ask Chiku streaming AI guide.</p>
    <div class="endpoints">
      <a class="ep" href="/qr-code/api/parks"><span>GET /qr-code/api/parks</span><span class="tag-ok">Active &rarr;</span></a>
      <div class="ep"><span>POST /qr-code/api/ai/chat</span><span class="tag-ai">Ask Chiku</span></div>
    </div>
    <p class="tip">Tip: Set <strong>FLUTTER_WEB_ORIGIN</strong> in Vercel Environment Variables to automatically redirect this URL to your Flutter Visitor App.</p>
  </section>
</body>
</html>`;

export function GET() {
  const flutterOrigin = resolveRedirectOrigin();
  if (flutterOrigin) {
    return NextResponse.redirect(flutterOrigin, 307);
  }
  return new NextResponse(STATUS_HTML, {
    status: 200,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}
