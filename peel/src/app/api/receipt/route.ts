import { NextRequest, NextResponse } from "next/server";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { WATCHER_RECEIPT_PROMPT, THINKER_EXPENSE_PROMPT } from "@/data/prompts";
import { getServiceSupabase } from "@/lib/supabase";

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || "");
const PRIYA_ID = "00000000-0000-0000-0000-000000000001";

export async function POST(req: NextRequest) {
  const db = getServiceSupabase();
  const sessionId = crypto.randomUUID();
  try {
    const { image } = await req.json();
    const matches = image.match(/^data:(.+);base64,(.+)$/);
    if (!matches) return NextResponse.json({ error: "Invalid image" }, { status: 400 });

    await db.from("agent_activity").insert({ user_id: PRIYA_ID, agent: "watcher", icon: "👁️", message: "Scanning receipt...", session_id: sessionId });

    const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });
    const watcherResult = await model.generateContent([
      { text: WATCHER_RECEIPT_PROMPT + "\n\nParse this receipt:" },
      { inlineData: { mimeType: matches[1], data: matches[2] } },
    ]);
    const receipt = JSON.parse(extractJSON(watcherResult.response.text()));

    await db.from("scanned_receipts").insert({
      user_id: PRIYA_ID, vendor_name: receipt.vendor_name, receipt_date: receipt.date,
      total_amount: receipt.total_amount, subtotal: receipt.subtotal,
      gst_hst_amount: receipt.gst_hst_amount, gst_hst_rate: receipt.gst_hst_rate,
      items: receipt.items, category: receipt.category,
      is_business_expense: receipt.is_business_expense, cra_form: receipt.cra_form,
      cra_line_item: receipt.cra_line_item, confidence: receipt.confidence, source: "upload",
    });

    await db.from("transactions").insert({
      user_id: PRIYA_ID, date: receipt.date || new Date().toISOString().split("T")[0],
      vendor: receipt.vendor_name, amount: receipt.total_amount, category: receipt.category,
      tx_type: "debit", account_name: "Visa", is_recurring: false,
      is_business: receipt.is_business_expense, spend_type: receipt.spend_type || "want",
    });

    await db.from("agent_activity").insert({ user_id: PRIYA_ID, agent: "watcher", icon: "👁️", message: `${receipt.vendor_name}, $${receipt.total_amount} — ${receipt.category}`, session_id: sessionId });

    const thinkerResult = await model.generateContent([{
      text: THINKER_EXPENSE_PROMPT + "\n\nNew expense:\n" + JSON.stringify({ new_expense: receipt, ytd_business_deductions: 4200, ytd_freelance_revenue: 7500 }),
    }]);
    const analysis = JSON.parse(extractJSON(thinkerResult.response.text()));

    for (const step of analysis.reasoning_steps || []) {
      await db.from("agent_activity").insert({ user_id: PRIYA_ID, agent: "thinker", icon: "🧠", message: step, session_id: sessionId });
    }
    await db.from("agent_activity").insert({ user_id: PRIYA_ID, agent: "doer", icon: "⚡", message: "Added to expense report.", session_id: sessionId });

    const { data: activityLog } = await db.from("agent_activity").select("agent, icon, message").eq("session_id", sessionId).order("created_at");
    return NextResponse.json({ receipt, analysis, activityLog, sessionId });
  } catch (error: any) {
    console.error("Receipt error:", error);
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
}

function extractJSON(text: string): string {
  const cb = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (cb) return cb[1].trim();
  const raw = text.match(/\{[\s\S]*\}/);
  if (raw) return raw[0];
  return text;
}
