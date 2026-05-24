// FILE: peel/src/app/api/purchase-check/route.ts
// General chat — calls Gemini for EVERY message, shows error if it fails

import { NextRequest, NextResponse } from "next/server";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { dbAdmin } from "@/lib/supabase";

const GEMINI_KEY = process.env.GEMINI_API_KEY;

const CHAT_PROMPT = `You are Peel, a casual witty AI financial copilot for young Canadians. You text like a smart friend who's great with money.

Rules:
- Lowercase, like iMessage
- 1-3 short messages, each 1-3 sentences
- Use specific dollar amounts when you have them
- Use emojis naturally (1-2 per message)
- Never say "I recommend" — say "here's the move"
- If they ask about a purchase: check their budget numbers and give honest advice
- If they ask a money question: teach them simply
- If they say hello or something random: be friendly, introduce yourself, ask what they want help with
- Reference their actual financial data when relevant

Return ONLY a JSON object: {"messages":[{"text":"..."}]}`;

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const { message, userId } = body;

    // Check if Gemini is configured
    if (!GEMINI_KEY) {
      return NextResponse.json({
        data: { messages: [
          { text: "⚠️ gemini API key is not configured on vercel. go to vercel → settings → environment variables → add GEMINI_API_KEY" },
        ]},
        wantsSpent: 0, remaining: 1540, wantsBudget: 1540,
        debug: "GEMINI_API_KEY is not set"
      });
    }

    const ai = new GoogleGenerativeAI(GEMINI_KEY);
    const db = dbAdmin();

    // Get financial context
    let context = "No financial data available yet.";
    if (userId) {
      try {
        const month = new Date().toISOString().slice(0, 7) + "-01";
        const [wR, nR, gR, pR, aR, rR] = await Promise.all([
          db.from("transactions").select("amount").eq("user_id", userId).eq("spend_type", "want").gte("date", month),
          db.from("transactions").select("amount").eq("user_id", userId).eq("spend_type", "need").gte("date", month),
          db.from("savings_goals").select("*").eq("user_id", userId).eq("status", "active"),
          db.from("user_profiles").select("*").eq("id", userId).maybeSingle(),
          db.from("accounts").select("name, balance").eq("user_id", userId),
          db.from("transactions").select("vendor, amount, category, spend_type").eq("user_id", userId).order("date", { ascending: false }).limit(15),
        ]);

        const wantsSpent = (wR.data || []).reduce((s: number, t: any) => s + Number(t.amount), 0);
        const needsSpent = (nR.data || []).reduce((s: number, t: any) => s + Number(t.amount), 0);
        const budget = pR.data?.monthly_wants_budget || 1540;

        context = JSON.stringify({
          user_name: pR.data?.name || "friend",
          monthly_wants_spent: Math.round(wantsSpent),
          monthly_needs_spent: Math.round(needsSpent),
          wants_budget: budget,
          wants_remaining: Math.round(budget - wantsSpent),
          accounts: aR.data || [],
          savings_goals: (gR.data || []).map((g: any) => ({ name: g.name, target: g.target_amount, current: g.current_amount })),
          recent_transactions: rR.data || [],
          total_transactions: (rR.data || []).length,
        });

        // Return budget info alongside response
        const wantsSpentRounded = Math.round(wantsSpent);
        const remaining = Math.round(budget - wantsSpent);

        // Call Gemini
        const model = ai.getGenerativeModel({ model: "gemini-1.5-flash" });
        const result = await model.generateContent([{
          text: CHAT_PROMPT + "\n\nUser's financial context:\n" + context + "\n\nUser says: " + (message || "hello"),
        }]);

        const raw = result.response.text();
        const parsed = JSON.parse(exJ(raw));

        if (parsed.messages && parsed.messages.length > 0) {
          return NextResponse.json({
            data: parsed,
            wantsSpent: wantsSpentRounded,
            remaining,
            wantsBudget: budget,
          });
        }

        // Gemini returned something but no messages
        return NextResponse.json({
          data: { messages: [{ text: "hmm i got confused for a sec. try asking again? 🍊" }] },
          wantsSpent: wantsSpentRounded, remaining, wantsBudget: budget,
          debug: "Gemini returned unparseable: " + raw.slice(0, 200),
        });

      } catch (dbErr: any) {
        // DB error fetching context — still try Gemini without context
        console.error("DB context error:", dbErr.message);
      }
    }

    // Fallback: call Gemini without financial context
    try {
      const model = ai.getGenerativeModel({ model: "gemini-1.5-flash" });
      const result = await model.generateContent([{
        text: CHAT_PROMPT + "\n\nNo financial data loaded yet.\n\nUser says: " + (message || "hello"),
      }]);
      const parsed = JSON.parse(exJ(result.response.text()));
      return NextResponse.json({ data: parsed, wantsSpent: 0, remaining: 1540, wantsBudget: 1540 });
    } catch (geminiErr: any) {
      console.error("Gemini error:", geminiErr.message);
      return NextResponse.json({
        data: { messages: [
          { text: "⚠️ gemini API error: " + geminiErr.message },
          { text: "check that your GEMINI_API_KEY is valid at aistudio.google.com/apikey" },
        ]},
        wantsSpent: 0, remaining: 1540, wantsBudget: 1540,
        debug: geminiErr.message,
      });
    }

  } catch (e: any) {
    console.error("Chat route crash:", e);
    return NextResponse.json({
      data: { messages: [{ text: "something broke: " + e.message }] },
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
