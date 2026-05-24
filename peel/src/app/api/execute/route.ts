import { NextRequest, NextResponse } from "next/server";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { DOER_PROMPT } from "@/data/prompts";
import { dbAdmin } from "@/lib/supabase";

const ai = process.env.GEMINI_API_KEY ? new GoogleGenerativeAI(process.env.GEMINI_API_KEY) : null;

const FALLBACK_EXEC = {
  execution_messages: [
    { text: "cancelling classpass... done. $49/mo back in your pocket 🎉", delay_ms: 800 },
    { text: "cancelling crave... done. $9.99/mo saved ✓", delay_ms: 700 },
    { text: "scheduling TFSA auto-contribution: $400/mo starting next month 📈", delay_ms: 900 },
    { text: "switching tangerine rewards to groceries/gas/recurring bills. +$127/yr ✓", delay_ms: 800 },
  ],
  completion_message: "all done. you just saved yourself $1,027/year in about 10 seconds. not bad 🍊",
  execution_steps: [
    { display_message: "Cancelling ClassPass $49/mo", icon: "⚡", delay_ms: 800 },
    { display_message: "Cancelling Crave $9.99/mo", icon: "⚡", delay_ms: 700 },
    { display_message: "TFSA auto-save $400/mo", icon: "⚡", delay_ms: 900 },
    { display_message: "Rewards → groceries/gas/recurring", icon: "⚡", delay_ms: 800 },
  ],
};

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const userId = body.userId;
    if (!userId) return NextResponse.json({ execution: FALLBACK_EXEC, updatedAccounts: [] });

    const db = dbAdmin();
    let exec = FALLBACK_EXEC;

    if (ai) {
      try {
        const model = ai.getGenerativeModel({ model: "gemini-2.0-flash-lite" });
        const r = await model.generateContent([{
          text: DOER_PROMPT + "\nActions: cancel ClassPass $49/mo + Crave $9.99/mo, schedule TFSA $400/mo, switch rewards to groceries/gas/recurring +$127/yr",
        }]);
        const parsed = JSON.parse(exJ(r.response.text()));
        if (parsed.execution_messages) exec = parsed;
      } catch (geminiErr: any) {
        console.error("Gemini execute failed, using fallback:", geminiErr.message);
      }
    }

    // Actually update the database
    try {
      await db.from("accounts").update({ balance: 3880 }).eq("user_id", userId).eq("account_type", "chequing");
      await db.from("accounts").update({ balance: 18700 }).eq("user_id", userId).eq("account_type", "tfsa");
      await db.from("user_profiles").update({
        rewards_categories: ["groceries", "gas", "recurring bills"],
        tfsa_contributed_ytd: 3200,
      }).eq("id", userId);
    } catch (dbErr: any) {
      console.error("DB update failed:", dbErr.message);
    }

    const { data: updated } = await db.from("accounts").select("*").eq("user_id", userId);
    return NextResponse.json({ execution: exec, updatedAccounts: updated || [] });
  } catch (e: any) {
    console.error("Execute route error:", e);
    return NextResponse.json({ execution: FALLBACK_EXEC, updatedAccounts: [] });
  }
}

function exJ(t: string): string {
  const c = t.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (c) return c[1].trim();
  const r = t.match(/\{[\s\S]*\}/);
  return r ? r[0] : t;
}
