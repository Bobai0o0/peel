import { NextRequest, NextResponse } from "next/server";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { PURCHASE_CHECK_PROMPT } from "@/data/prompts";
import { getServiceSupabase } from "@/lib/supabase";

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || "");
const PRIYA_ID = "00000000-0000-0000-0000-000000000001";

export async function POST(req: NextRequest) {
  const db = getServiceSupabase();
  try {
    const { message } = await req.json();

    // Get current month's want spending
    const startOfMonth = new Date().toISOString().slice(0, 7) + "-01";
    const { data: wantsTxns } = await db.from("transactions")
      .select("amount").eq("user_id", PRIYA_ID)
      .eq("spend_type", "want").gte("date", startOfMonth);

    const wantsSpent = (wantsTxns || []).reduce((s: number, t: any) => s + Number(t.amount), 0);
    const wantsBudget = 1540;
    const remaining = wantsBudget - wantsSpent;

    // Get savings goals
    const { data: goals } = await db.from("savings_goals").select("*")
      .eq("user_id", PRIYA_ID).eq("status", "active");

    const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });
    const result = await model.generateContent([{
      text: PURCHASE_CHECK_PROMPT + "\n\nUser says: " + message +
        "\n\nBudget context: " + JSON.stringify({
          wants_spent_this_month: wantsSpent,
          wants_budget: wantsBudget,
          wants_remaining: remaining,
          savings_goals: (goals || []).map((g: any) => ({
            name: g.name, target: g.target_amount, current: g.current_amount, target_date: g.target_date,
          })),
        }),
    }]);

    const data = JSON.parse(extractJSON(result.response.text()));

    // Save to purchase_checks table
    await db.from("purchase_checks").insert({
      user_id: PRIYA_ID, item_description: message,
      estimated_price: data.context?.estimated_price || null,
      ai_response: JSON.stringify(data), verdict: data.verdict,
      monthly_spent_so_far: wantsSpent, monthly_remaining: remaining,
    });

    return NextResponse.json({ data, wantsSpent, remaining, wantsBudget });
  } catch (error: any) {
    console.error("Purchase check error:", error);
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
