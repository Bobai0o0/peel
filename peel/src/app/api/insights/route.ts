// FILE: peel/src/app/api/insights/route.ts

import { NextRequest, NextResponse } from "next/server";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { INSIGHTS_PROMPT } from "@/data/prompts";
import { dbAdmin } from "@/lib/supabase";

const ai = process.env.GEMINI_API_KEY ? new GoogleGenerativeAI(process.env.GEMINI_API_KEY) : null;

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const userId = body.userId;
    if (!userId) return NextResponse.json({ data: { messages: [{ id: "1", type: "greeting", text: "hey! sign in first so i can look at your finances 🍊" }] }, activityLog: [] });

    const db = dbAdmin();

    // Fetch THIS user's actual data
    const [p, tx, ac, g] = await Promise.all([
      db.from("user_profiles").select("*").eq("id", userId).maybeSingle(),
      db.from("transactions").select("*").eq("user_id", userId).order("date", { ascending: false }),
      db.from("accounts").select("*").eq("user_id", userId),
      db.from("savings_goals").select("*").eq("user_id", userId).eq("status", "active"),
    ]);

    const transactions = tx.data || [];
    const accounts = ac.data || [];
    const goals = g.data || [];
    const profile = p.data;

    // If user has no transactions, tell them to upload receipts
    if (transactions.length === 0) {
      return NextResponse.json({
        data: {
          messages: [
            { id: "1", type: "greeting", text: "hey " + (profile?.name || "there") + "! 👋 i don't have any transaction data for you yet." },
            { id: "2", type: "insight", text: "try scanning a few receipts first — snap a photo or upload a screenshot. once i have some data, i can find patterns and savings opportunities for you 📸" },
            { id: "3", type: "insight", text: "you can also just chat with me! ask me anything about budgeting, TFSAs, taxes, or whether you should buy something 🍊" },
          ],
          total_annual_opportunity: 0,
          agent_log: [
            { agent: "watcher", icon: "👁️", message: "No transactions found for this user" },
            { agent: "thinker", icon: "🧠", message: "Waiting for receipt uploads to analyze" },
          ],
        },
        activityLog: [
          { agent: "watcher", icon: "👁️", message: "No transactions found" },
          { agent: "thinker", icon: "🧠", message: "Scan some receipts to get started" },
        ],
      });
    }

    // Build summary from THIS user's real data
    const txSummary = {
      user: {
        name: profile?.name,
        salary: profile?.salary,
        freelance_ytd: profile?.freelance_ytd,
        tfsa_contributed_ytd: profile?.tfsa_contributed_ytd,
        tfsa_limit: profile?.tfsa_limit,
        rewards_categories: profile?.rewards_categories,
        monthly_wants_budget: profile?.monthly_wants_budget,
        accounts: accounts.map((a: any) => ({ name: a.name, type: a.account_type, balance: a.balance, institution: a.institution })),
      },
      savings_goals: goals.map((g: any) => ({ name: g.name, target: g.target_amount, current: g.current_amount, target_date: g.target_date })),
      transactions: transactions.map((t: any) => ({
        date: t.date, vendor: t.vendor, amount: t.amount, category: t.category,
        type: t.tx_type, is_recurring: t.is_recurring, is_business: t.is_business, spend_type: t.spend_type,
      })),
      current_date: new Date().toISOString().slice(0, 10),
    };

    // Call Gemini with the user's actual data
    if (ai) {
      try {
        const model = ai.getGenerativeModel({ model: "gemini-2.0-flash-lite" });
        const r = await model.generateContent([{
          text: INSIGHTS_PROMPT + "\n\nThis user's actual financial data:\n" + JSON.stringify(txSummary),
        }]);

        const text = r.response.text();
        const parsed = JSON.parse(exJ(text));

        if (parsed.messages && parsed.messages.length > 0) {
          // Save insights to DB
          for (const msg of parsed.messages) {
            if (msg.insight_data?.type) {
              try {
                await db.from("insights").insert({
                  user_id: userId, insight_type: msg.insight_data.type,
                  headline: (msg.text || "").slice(0, 100), detail: msg.text,
                  annual_value: msg.insight_data.annual_value, status: "pending",
                });
              } catch {}
            }
          }

          const activityLog = parsed.agent_log || [
            { agent: "watcher", icon: "👁️", message: "Scanned " + transactions.length + " transactions" },
            { agent: "thinker", icon: "🧠", message: "Analysis complete" },
          ];

          return NextResponse.json({ data: parsed, activityLog });
        }
      } catch (geminiErr: any) {
        console.error("Gemini insights error:", geminiErr.message);
      }
    }

    // Gemini failed — give a basic summary from real data, not hardcoded
    const wantTotal = transactions.filter((t: any) => t.spend_type === "want").reduce((s: number, t: any) => s + Number(t.amount), 0);
    const needTotal = transactions.filter((t: any) => t.spend_type === "need").reduce((s: number, t: any) => s + Number(t.amount), 0);
    const savingsTotal = transactions.filter((t: any) => t.spend_type === "savings").reduce((s: number, t: any) => s + Number(t.amount), 0);
    const totalBalance = accounts.reduce((s: number, a: any) => s + Number(a.balance), 0);

    return NextResponse.json({
      data: {
        messages: [
          { id: "1", type: "greeting", text: "hey " + (profile?.name || "there") + "! here's what i see in your " + transactions.length + " transactions 👀" },
          { id: "2", type: "budget", text: "total spending: $" + Math.round(needTotal) + " on needs, $" + Math.round(wantTotal) + " on wants, $" + Math.round(savingsTotal) + " on savings. account balance: $" + Math.round(totalBalance) + ".", insight_data: { type: "needs_wants", annual_value: null } },
          { id: "3", type: "insight", text: "keep scanning receipts and i'll find more patterns and savings opportunities for you! ask me anything in the meantime 🍊" },
        ],
        total_annual_opportunity: 0,
        agent_log: [
          { agent: "watcher", icon: "👁️", message: "Scanned " + transactions.length + " transactions" },
          { agent: "thinker", icon: "🧠", message: "Needs: $" + Math.round(needTotal) + " | Wants: $" + Math.round(wantTotal) },
        ],
      },
      activityLog: [
        { agent: "watcher", icon: "👁️", message: "Scanned " + transactions.length + " transactions" },
        { agent: "thinker", icon: "🧠", message: "Basic analysis complete" },
      ],
    });
  } catch (e: any) {
    console.error("Insights route error:", e);
    return NextResponse.json({
      data: { messages: [{ id: "1", type: "greeting", text: "something went wrong analyzing your data. try again? 🍊" }] },
      activityLog: [],
    });
  }
}

function exJ(t: string): string {
  const c = t.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (c) return c[1].trim();
  const r = t.match(/\{[\s\S]*\}/);
  return r ? r[0] : t;
}
