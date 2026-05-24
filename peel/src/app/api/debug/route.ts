import { NextRequest, NextResponse } from "next/server";

export async function GET(req: NextRequest) {
  return NextResponse.json({
    gemini_key_set: !!process.env.GEMINI_API_KEY,
    gemini_key_preview: process.env.GEMINI_API_KEY ? process.env.GEMINI_API_KEY.slice(0, 8) + "..." : "NOT SET",
    supabase_url_set: !!process.env.NEXT_PUBLIC_SUPABASE_URL,
    supabase_anon_set: !!process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
    supabase_service_set: !!process.env.SUPABASE_SERVICE_ROLE_KEY,
  });
}