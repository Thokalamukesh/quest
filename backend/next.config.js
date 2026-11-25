/** @type {import('next').NextConfig} */
const nextConfig = {
  serverExternalPackages: ["genkit", "@genkit-ai/google-genai"],
  async rewrites() {
    return {
      beforeFiles:
        process.env.SERVE_FLUTTER_WEB === "1"
          ? [{ source: "/", destination: "/index.html" }]
          : [],
    };
  },
  // Keep `next dev` output separate from `next build`; sharing `.next` can
  // leave stale server chunks behind when switching between the two modes.
  distDir: process.env.NODE_ENV === "development" ? ".next-dev" : ".next",
};
module.exports = nextConfig;
