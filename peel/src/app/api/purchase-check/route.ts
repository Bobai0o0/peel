import { NextRequest, NextResponse } from "next/server";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { PURCHASE_PROMPT } from "@/data/prompts";
import { dbAdmin } from "@/lib/supabase";

const ai = process.env.GEMINI_API_KEY ? new GoogleGenerativeAI(process.env.GEMINI_API_KEY) : null;

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const { message, userId } = body;
    if (!userId) {
      return NextResponse.json({
        data: { verdict: "maybe_wait", messages: [{ text: "hmm i need to check your budget first. try loading your demo data!" }] },
        wantsSpent: 0, remaining: 1540, wantsBudget: 1540,
      });
    }

    const db = dbAdmin();
    const month = new Date().toISOString().slice(0, 7) + "-01";
    const { data: w } = await db.from("transactions").select("amount").eq("user_id", userId).eq("spend_type", "want").gte("date", month);
    const spent = (w || []).reduce((s: number, t: any) => s + Number(t.amount), 0);
    const budget = 1540;
    const remaining = budget - spent;
    const { data: goals } = await db.from("savings_goals").select("*").eq("user_id", userId).eq("status", "active");

    let data: any = null;

    if (ai) {
      try {
        const model = ai.getGenerativeModel({ model: "gemini-1.5-flash" });
        const r = await model.generateContent([{
          text: PURCHASE_PROMPT + "\nUser: " + (message || "should I buy this?") + "\nBudget: " + JSON.stringify({
            wants_spent: spent, wants_budget: budget, remaining,
            goals: (goals || []).map((g: any) => ({ name: g.name, target: g.target_amount, current: g.current_amount })),
          }),
        }]);
        data = JSON.parse(exJ(r.response.text()));
      } catch (geminiErr: any) {
        console.error("Gemini purchase check failed:", geminiErr.message);
      }
    }

    if (!data) {
      const over = remaining < 0;
      data = {
        verdict: remaining > 200 ? "go_for_it" : remaining > 0 ? "maybe_wait" : "skip_it",
        messages: [
          { text: `you've spent $${Math.round(spent)} on wants this month out of your $${budget} budget. that leaves $${Math.round(remaining)}.` },
          { text: remaining > 200
            ? "you've got room! treat yourself 🎉"
            : remaining > 0
            ? "it's tight. maybe wait till next month? your call though 💛"
            : "you're over budget this month. screenshot it and revisit next month? 📸"
          },
        ],
      };
    }

    return NextResponse.json({ data, wantsSpent: spent, remaining, wantsBudget: budget });
  } catch (e: any) {
    console.error("Purchase check error:", e);
    return NextResponse.json({
      data: { verdict: "maybe_wait", messages: [{ text: "had trouble checking your budget. try again in a sec?" }] },
      wantsSpent: 0, remaining: 1540, wantsBudget: 1540,
    });
  }
}

function exJ(t: string): string {
  const c = t.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (c) return c[1].trim();
  const r = t.match(/\{[\s\S]*\}/);
  return r ? r[0] : t;
}
