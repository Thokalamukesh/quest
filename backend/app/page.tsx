import { redirect } from "next/navigation";

export const dynamic = "force-dynamic";

function resolveRedirectOrigin(): string | null {
  const raw = process.env.FLUTTER_WEB_ORIGIN ?? "";
  const first = raw
    .split(",")
    .map((item) => item.trim())
    .find((item) => /^https?:\/\//i.test(item));
  return first ?? null;
}

export default function Home() {
  const flutterOrigin = resolveRedirectOrigin();
  if (flutterOrigin) {
    redirect(flutterOrigin);
  }

  return (
    <main
      style={{
        minHeight: "100vh",
        margin: 0,
        padding: "32px 20px",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        background: "linear-gradient(155deg, #0F2357 0%, #1F44A8 100%)",
        fontFamily:
          'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
        color: "#0F2357",
      }}
    >
      <section
        style={{
          width: "100%",
          maxWidth: 520,
          background: "#FFFFFF",
          borderRadius: 24,
          padding: "28px 26px",
          boxShadow: "0 24px 60px rgba(9, 20, 56, 0.32)",
        }}
      >
        <div
          style={{
            display: "inline-flex",
            alignItems: "center",
            gap: 8,
            padding: "6px 12px",
            borderRadius: 999,
            background: "#ECF9F2",
            border: "1px solid #BBE7CF",
            color: "#15803D",
            fontSize: 12.5,
            fontWeight: 700,
            marginBottom: 14,
          }}
        >
          <span
            style={{
              width: 8,
              height: 8,
              borderRadius: "50%",
              background: "#22C55E",
              display: "inline-block",
            }}
          />
          API Server Online
        </div>

        <h1
          style={{
            margin: "0 0 8px",
            fontSize: 24,
            fontWeight: 800,
            letterSpacing: "-0.02em",
            color: "#0F2357",
          }}
        >
          Wonderla Visitor &amp; Ask Chiku API
        </h1>

        <p
          style={{
            margin: "0 0 20px",
            fontSize: 14.5,
            lineHeight: 1.55,
            color: "#4B5D7C",
          }}
        >
          This service powers the Flutter Visitor App, Admin CMS, park maps, and
          Ask Chiku streaming AI concierge.
        </p>

        <div
          style={{
            display: "grid",
            gap: 10,
            marginBottom: 18,
          }}
        >
          <a
            href="/qr-code/api/parks"
            style={{
              display: "flex",
              alignItems: "center",
              justifyContent: "space-between",
              padding: "12px 14px",
              borderRadius: 14,
              background: "#F4F7FC",
              border: "1px solid #DCE5F5",
              color: "#1F44A8",
              textDecoration: "none",
              fontWeight: 700,
              fontSize: 13.5,
            }}
          >
            <span>GET /qr-code/api/parks</span>
            <span style={{ color: "#15803D", fontSize: 12 }}>Active →</span>
          </a>

          <div
            style={{
              display: "flex",
              alignItems: "center",
              justifyContent: "space-between",
              padding: "12px 14px",
              borderRadius: 14,
              background: "#F4F7FC",
              border: "1px solid #DCE5F5",
              color: "#0F2357",
              fontWeight: 700,
              fontSize: 13.5,
            }}
          >
            <span>POST /qr-code/api/ai/chat</span>
            <span style={{ color: "#1F44A8", fontSize: 12 }}>Ask Chiku</span>
          </div>
        </div>

        <p
          style={{
            margin: 0,
            padding: "11px 13px",
            borderRadius: 12,
            background: "#FFFBEB",
            border: "1px solid #FDE68A",
            color: "#78350F",
            fontSize: 12.5,
            lineHeight: 1.45,
          }}
        >
          Tip: Set <strong>FLUTTER_WEB_ORIGIN</strong> in Vercel Environment
          Variables to automatically redirect this URL to your Flutter Visitor
          App.
        </p>
      </section>
    </main>
  );
}
