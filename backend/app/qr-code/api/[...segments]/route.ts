import { NextResponse } from "next/server";

function apiNotFound() {
  return NextResponse.json(
    { ok: false, error: "API endpoint not found" },
    { status: 404 },
  );
}

export const GET = apiNotFound;
export const POST = apiNotFound;
export const PUT = apiNotFound;
export const PATCH = apiNotFound;
export const DELETE = apiNotFound;