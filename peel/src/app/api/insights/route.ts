import { NextRequest, NextResponse } from "next/server";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { THINKER_INSIGHTS_PROMPT } from "@/data/prompts";
import { getServiceSupabase } from "@/lib/supabase";

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || "");
const PRIYA_ID = "00000000-0000-0000-0000-000000000001";

export async function POST(req: NextRequest) {
  const db = getServiceSupabase();
  const sessionId = crypto.randomUUID();
  try {
    const [profileRes, txRes, accountsRes, goalsRes] = await Promise.all([
      db.from("user_profiles").select("*").eq("id", PRIYA_ID).single(),
      db.from("transactions").select("*").eq("user_id", PRIYA_ID).order("date", { ascending: false }),
      db.from("accounts").select("*").eq("user_id", PRIYA_ID),
      db.from("savings_goals").select("*").eq("user_id", PRIYA_ID).eq("status", "active"),
    ]);

    const profile = profileRes.data;
    const transactions = txRes.data || [];
    const accounts = accountsRes.data || [];
    const goals = goalsRes.data || [];

    await db.from("agent_activity").insert([
      { user_id: PRIYA_ID, agent: "orchestrator", icon: "🔄", message: "Starting analysis...", session_id: sessionId },
      { user_id: PRIYA_ID, agent: "watcher", icon: "👁️", message: `Scanning ${transactions.length} transactions`, session_id: sessionId },
    ]);

    const txSummary = {
      user: {
        name: profile?.name, age: profile?.age, salary: profile?.salary,
        freelance_ytd: profile?.freelance_ytd, tfsa_contributed_ytd: profile?.tfsa_contributed_ytd,
        tfsa_limit: profile?.tfsa_limit, tangerine_rewards_categories: profile?.rewards_categories,
        monthly_needs_budget: profile?.monthly_needs_budget, monthly_wants_budget: profile?.monthly_wants_budget,
        accounts: accounts.map((a: any) => ({ name: a.name, type: a.account_type, balance: a.balance, institution: a.institution })),
      },
      savings_goals: goals.map((g: any) => ({ name: g.name, target: g.target_amount, current: g.current_amount, target_date: g.target_date })),
      transactions: transactions.map((t: any) => ({
        date: t.date, vendor: t.vendor, amount: t.amount, category: t.category,
        type: t.tx_type, is_recurring: t.is_recurring, is_business: t.is_business, spend_type: t.spend_type,
      })),
      current_date: "2026-05-24",
    };

    const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });
    const result = await model.generateContent([{ text: THINKER_INSIGHTS_PROMPT + "\n\nData:\n" + JSON.stringify(txSummary) }]);
    const data = JSON.parse(extractJSON(result.response.text()));

    for (const entry of data.agent_log || []) {
      await db.from("agent_activity").insert({ user_id: PRIYA_ID, agent: entry.agent, icon: entry.icon, message: entry.message, session_id: sessionId });
    }
    for (const msg of data.messages || []) {
      if (msg.insight_data?.type) {
        await db.from("insights").insert({
          user_id: PRIYA_ID, insight_type: msg.insight_data.type, emoji: msg.emoji,
          headline: (msg.text || "").substring(0, 100), detail: msg.text,
          annual_value: msg.insight_data.annual_value, action_label: msg.insight_data.action_label,
          action_id: msg.insight_data.action_id, status: "pending",
        });
      }
    }

    const { data: activityLog } = await db.from("agent_activity").select("agent, icon, message").eq("session_id", sessionId).order("created_at");
    return NextResponse.json({ data, activityLog, sessionId });
  } catch (error: any) {
    console.error("Insights error:", error);
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
