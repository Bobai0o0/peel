// FILE: peel/src/app/api/purchase-check/route.ts
// This is now a GENERAL CHAT endpoint — handles any message with Gemini

import { NextRequest, NextResponse } from "next/server";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { dbAdmin } from "@/lib/supabase";

const ai = process.env.GEMINI_API_KEY ? new GoogleGenerativeAI(process.env.GEMINI_API_KEY) : null;

const CHAT_PROMPT = `You are Peel, a casual, witty AI financial copilot for young Canadians. You text like a smart friend who's great with money.

You have the user's financial context below. Use it to answer ANY question they ask — whether it's about a purchase, a financial concept, their spending, their goals, or just a random money question.

TONE RULES:
- Lowercase, like iMessage
- Specific dollar amounts when relevant
- Never say "I recommend" — say "here's the move" or "quick thought"
- Supportive, never preachy or judgmental
- Use emojis naturally (1-2 per message)
- If they ask about a purchase: check their budget and goals, give honest advice
- If they ask a general money question: teach them in plain language
- If they ask about their spending: reference actual numbers from their data
- If the message doesn't relate to money at all: still be friendly, but gently steer back to finances

Return ONLY JSON:
{"messages":[{"text": string}]}
Return 1-3 messages. Each should be 1-3 sentences.`;

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const { message, userId } = body;
    if (!userId) {
      return NextResponse.json({
        data: { messages: [{ text: "hey! sign in first and i can help you with your money 🍊" }] },
        wantsSpent: 0, remaining: 1540, wantsBudget: 1540,
      });
    }

    const db = dbAdmin();

    // Get user's financial context
    const month = new Date().toISOString().slice(0, 7) + "-01";
    const [wantsRes, needsRes, goalsRes, profileRes, accountsRes, recentRes] = await Promise.all([
      db.from("transactions").select("amount").eq("user_id", userId).eq("spend_type", "want").gte("date", month),
      db.from("transactions").select("amount").eq("user_id", userId).eq("spend_type", "need").gte("date", month),
      db.from("savings_goals").select("*").eq("user_id", userId).eq("status", "active"),
      db.from("user_profiles").select("*").eq("id", userId).maybeSingle(),
      db.from("accounts").select("*").eq("user_id", userId),
      db.from("transactions").select("vendor, amount, category, spend_type, date").eq("user_id", userId).order("date", { ascending: false }).limit(20),
    ]);

    const wantsSpent = (wantsRes.data || []).reduce((s: number, t: any) => s + Number(t.amount), 0);
    const needsSpent = (needsRes.data || []).reduce((s: number, t: any) => s + Number(t.amount), 0);
    const budget = profileRes.data?.monthly_wants_budget || 1540;
    const remaining = budget - wantsSpent;
    const goals = goalsRes.data || [];
    const accounts = accountsRes.data || [];
    const recent = recentRes.data || [];
    const totalBalance = accounts.reduce((s: number, a: any) => s + Number(a.balance), 0);

    // Try Gemini first
    if (ai && message) {
      try {
        const model = ai.getGenerativeModel({ model: "gemini-1.5-flash" });
        const context = JSON.stringify({
          user_message: message,
          monthly_wants_spent: wantsSpent,
          monthly_needs_spent: needsSpent,
          wants_budget: budget,
          wants_remaining: remaining,
          total_balance: totalBalance,
          accounts: accounts.map((a: any) => ({ name: a.name, balance: a.balance })),
          savings_goals: goals.map((g: any) => ({ name: g.name, target: g.target_amount, current: g.current_amount })),
          recent_transactions: recent.slice(0, 10),
        });

        const r = await model.generateContent([{
          text: CHAT_PROMPT + "\n\nFinancial context:\n" + context + "\n\nUser says: " + message,
        }]);

        const text = r.response.text();
        const parsed = JSON.parse(exJ(text));

        if (parsed.messages && parsed.messages.length > 0) {
          return NextResponse.json({
            data: parsed,
            wantsSpent, remaining, wantsBudget: budget,
          });
        }
      } catch (geminiErr: any) {
        console.error("Gemini chat error:", geminiErr.message);
        // Fall through to fallback
      }
    }

    // Fallback: basic budget response
    const data = {
      messages: [
        { text: `you've spent $${Math.round(wantsSpent)} on wants this month out of your $${budget} budget. that leaves $${Math.round(remaining)}.` },
        remaining > 200
          ? { text: "you've got room! what are you thinking of getting? 🍊" }
          : remaining > 0
          ? { text: "budget's getting tight this month. what's on your mind?" }
          : { text: "you're over budget on wants this month. let's figure out what to do 💛" },
      ],
    };

    return NextResponse.json({ data, wantsSpent, remaining, wantsBudget: budget });
  } catch (e: any) {
    console.error("Chat error:", e);
    return NextResponse.json({
      data: { messages: [{ text: "had trouble processing that. try again in a sec? 🍊" }] },
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
