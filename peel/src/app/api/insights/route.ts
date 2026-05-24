import { NextRequest, NextResponse } from "next/server";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { INSIGHTS_PROMPT } from "@/data/prompts";
import { dbAdmin } from "@/lib/supabase";
const ai = new GoogleGenerativeAI(process.env.GEMINI_API_KEY!);

export async function POST(req: NextRequest) {
  const db = dbAdmin();
  const { userId } = await req.json();
  if (!userId) return NextResponse.json({ error: "No user" }, { status: 400 });
  const sid = crypto.randomUUID();

  const [p,tx,ac,g] = await Promise.all([
    db.from("user_profiles").select("*").eq("id",userId).single(),
    db.from("transactions").select("*").eq("user_id",userId).order("date",{ascending:false}),
    db.from("accounts").select("*").eq("user_id",userId),
    db.from("savings_goals").select("*").eq("user_id",userId).eq("status","active"),
  ]);

  const model = ai.getGenerativeModel({ model: "gemini-1.5-flash" });
  const r = await model.generateContent([{ text: INSIGHTS_PROMPT + "\n\nData:\n" + JSON.stringify({
    user:p.data, accounts:ac.data, goals:g.data,
    transactions:(tx.data||[]).map(t=>({date:t.date,vendor:t.vendor,amount:t.amount,category:t.category,type:t.tx_type,is_recurring:t.is_recurring,spend_type:t.spend_type})),
    current_date:new Date().toISOString().slice(0,10),
  })}]);

  const data = JSON.parse(exJ(r.response.text()));
  for (const e of data.agent_log||[]) await db.from("agent_activity").insert({...e,user_id:userId,session_id:sid});
  return NextResponse.json({ data, activityLog:data.agent_log||[] });
}
function exJ(t){const c=t.match(/```(?:json)?\s*([\s\S]*?)```/);if(c)return c[1].trim();const r=t.match(/\{[\s\S]*\}/);return r?r[0]:t}
