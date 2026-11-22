import { NextRequest, NextResponse } from "next/server";
import {
  streamWonderlaAssistant,
  type AiChatHistoryItem,
  type AiStreamEvent,
} from "../../../_lib/wonderla-ai";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(req: NextRequest) {
  let body: {
    parkSlug?: string;
    message?: string;
    history?: AiChatHistoryItem[];
  };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json(
      { ok: false, error: "Invalid JSON body." },
      { status: 400 },
    );
  }

  const parkSlug = (body.parkSlug ?? "").trim();
  const message = (body.message ?? "").trim();
  if (!parkSlug || !message) {
    return NextResponse.json(
      { ok: false, error: "parkSlug and message are required." },
      { status: 400 },
    );
  }

  const encoder = new TextEncoder();
  const stream = new ReadableStream({
    async start(controller) {
      const send = (event: AiStreamEvent) => {
        try {
          controller.enqueue(encoder.encode(`${JSON.stringify(event)}\n`));
        } catch {
          // Stream already closed by client.
        }
      };

      try {
        await streamWonderlaAssistant({
          parkSlug,
          message,
          history: Array.isArray(body.history) ? body.history : [],
          onEvent: send,
        });
      } catch (err) {
        const errorMessage =
          err instanceof Error ? err.message : "Could not generate AI response.";
        send({ type: "error", message: errorMessage });
      } finally {
        try {
          controller.close();
        } catch {
          // Ignore double-close.
        }
      }
    },
  });

  return new Response(stream, {
    headers: {
      "Content-Type": "application/x-ndjson; charset=utf-8",
      "Cache-Control": "no-cache, no-transform",
      "X-Accel-Buffering": "no",
    },
  });
}
