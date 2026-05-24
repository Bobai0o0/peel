import { NextRequest, NextResponse } from "next/server";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { DOER_NARRATIVE_PROMPT } from "@/data/prompts";
import { getServiceSupabase } from "@/lib/supabase";

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || "");
const PRIYA_ID = "00000000-0000-0000-0000-000000000001";

export async function POST(req: NextRequest) {
  const db = getServiceSupabase();
  const sessionId = crypto.randomUUID();
  try {
    const { actions } = await req.json();
    const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });

    const defaultActions = [
      { action_id: "cancel_subs", label: "Cancel subscriptions", details: "ClassPass $49/mo + Crave $9.99/mo = $707.88/yr" },
      { action_id: "tfsa_auto", label: "TFSA auto-save", details: "$400/mo. Balance $18,300. Room $4,200." },
      { action_id: "switch_rewards", label: "Optimize rewards", details: "Switch to groceries/gas/recurring. +$127/yr" },
    ];

    const result = await model.generateContent([{ text: DOER_NARRATIVE_PROMPT + "\n\nExecute:\n" + JSON.stringify({ actions_to_execute: actions || defaultActions }) }]);
    const execution = JSON.parse(extractJSON(result.response.text()));

    for (const step of execution.execution_steps || []) {
      await db.from("agent_activity").insert({ user_id: PRIYA_ID, agent: "doer", icon: "⚡", message: step.display_message, session_id: sessionId });
    }

    await db.from("executed_actions").insert({ user_id: PRIYA_ID, action_id: "fix_all", action_label: "Fix all three", execution_steps: execution.execution_steps, completion_summary: execution.completion_message, status: "completed" });
    await db.from("insights").update({ status: "approved" }).eq("user_id", PRIYA_ID).eq("status", "pending");
    await db.from("accounts").update({ balance: 3880 }).eq("user_id", PRIYA_ID).eq("account_type", "chequing");
    await db.from("accounts").update({ balance: 18700 }).eq("user_id", PRIYA_ID).eq("account_type", "tfsa");
    await db.from("user_profiles").update({ rewards_categories: ["groceries", "gas", "recurring bills"], tfsa_contributed_ytd: 3200 }).eq("id", PRIYA_ID);

    if (execution.completion_message) {
      await db.from("agent_activity").insert({ user_id: PRIYA_ID, agent: "doer", icon: "✅", message: execution.completion_message, session_id: sessionId });
    }

    const { data: updatedAccounts } = await db.from("accounts").select("*").eq("user_id", PRIYA_ID);
    const { data: activityLog } = await db.from("agent_activity").select("agent, icon, message").eq("session_id", sessionId).order("created_at");
    return NextResponse.json({ execution, activityLog, updatedAccounts, sessionId });
  } catch (error: any) {
    console.error("Execute error:", error);
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
