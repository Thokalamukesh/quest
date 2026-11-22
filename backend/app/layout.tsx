import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Wonderla Park API",
  description: "Backend API for Wonderla Visitor Flutter App, CMS, and Ask Chiku",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body style={{ margin: 0 }}>{children}</body>
    </html>
  );
}
