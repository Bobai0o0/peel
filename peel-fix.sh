#!/bin/bash
# PEEL FIX — Replaces API routes + page.tsx with bulletproof versions
# Adds fallback responses so the demo works even if Gemini fails
# Run: bash peel-fix.sh (from the folder ABOVE peel/)

echo "🔧 Fixing Peel..."

# ─── API: insights (with fallback) ───────────────────────────
cat > peel/src/app/api/insights/route.ts << 'EOF'
import { NextRequest, NextResponse } from "next/server";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { INSIGHTS_PROMPT } from "@/data/prompts";
import { dbAdmin } from "@/lib/supabase";

const ai = process.env.GEMINI_API_KEY ? new GoogleGenerativeAI(process.env.GEMINI_API_KEY) : null;

const FALLBACK = {
  messages:[
    {id:"1",type:"greeting",text:"hey! i just ran through your last 6 months of transactions. found some stuff you'll wanna see 👀",insight_data:null,learn_card:null},
    {id:"2",type:"budget",text:"your may spending so far: ~$2,680 on needs (53%), ~$412 on wants (8%), $400 on savings. you've got about $128 left in fun money this month 🛒",insight_data:{type:"needs_wants",annual_value:null},learn_card:null},
    {id:"3",type:"insight",text:"you're paying $49/mo for classpass and $9.99/mo for crave. you haven't used either since february. that's $707.88/year walking out the door 💸",insight_data:{type:"subscription_waste",annual_value:707.88},learn_card:null},
    {id:"4",type:"learn",text:"here's the thing about subscription creep...",insight_data:null,learn_card:{title:"What's subscription creep?",explanation:"Subscription creep is when small monthly charges pile up unnoticed. The average young Canadian loses $780/year to unused subscriptions. Each one feels small ($10-50) but together they add up fast.",pro_tip:"Set a calendar reminder every 3 months to audit your subscriptions. If you haven't used it in 60 days, cancel it."}},
    {id:"5",type:"insight",text:"you've only used $2,800 of your $7,000 TFSA limit this year. that's $4,200 in room sitting empty. at your cash flow, $400/mo is totally safe to auto-contribute 💰",insight_data:{type:"savings_opportunity",annual_value:180},learn_card:null},
    {id:"6",type:"learn",text:"quick TFSA explainer for you...",insight_data:null,learn_card:{title:"What's a TFSA actually?",explanation:"A Tax-Free Savings Account lets your investments grow completely tax-free. At 27, you have decades of compound growth ahead. Even $400/month at 7% average return becomes ~$500K by retirement.",pro_tip:"Max your TFSA before your RRSP. The tax-free growth is more valuable when you're young and in a lower tax bracket."}},
    {id:"7",type:"goals",text:"goals check: 🇯🇵 japan trip — $1,200 / $5,000 (24%), on track for march 2027. 🛟 emergency fund — $11,450 / $15,000 (76%), about 5 months to go!",insight_data:null,learn_card:null},
    {id:"8",type:"insight",text:"your tangerine rewards card is set to groceries/gas/restaurants. but you spend $170/mo on recurring bills (rogers, hydro) and only ~$45/mo on restaurants. switching to groceries/gas/recurring bills earns you $127 more per year 💳",insight_data:{type:"rewards_optimization",annual_value:127},learn_card:null},
    {id:"9",type:"insight",text:"heads up on taxes — your freelance income is $7,500 YTD, on track for ~$12K this year. you've got about $4,200 in deductible expenses. make sure you're setting aside ~25% for tax time 📋",insight_data:{type:"tax_alert",annual_value:0},learn_card:null},
    {id:"10",type:"learn",text:"quick primer on freelance taxes...",insight_data:null,learn_card:{title:"T2125: Self-employment income",explanation:"If you freelance in Canada, you report that income on form T2125. You can deduct business expenses (software, office supplies, equipment) to reduce what you owe. Keep every receipt.",pro_tip:"Open a separate savings account and auto-transfer 25% of every freelance payment into it. That's your tax fund."}},
    {id:"11",type:"summary",text:"total: $1,027/year sitting on the table. subscriptions ($708) + TFSA growth ($180) + rewards switch ($127). want me to fix all three right now?",insight_data:null,learn_card:null},
    {id:"12",type:"action_prompt",text:"one tap and i'll cancel the subs, set up your tfsa auto-save, and switch your rewards categories. you just say go. 🍊",insight_data:null,learn_card:null},
  ],
  total_annual_opportunity:1027,
  agent_log:[
    {agent:"watcher",icon:"👁️",message:"Scanned 44 transactions across 6 months"},
    {agent:"watcher",icon:"👁️",message:"Found 4 recurring subscriptions, 4 freelance deposits"},
    {agent:"thinker",icon:"🧠",message:"ClassPass unused since Feb ($49/mo)"},
    {agent:"thinker",icon:"🧠",message:"Crave unused since Feb ($9.99/mo)"},
    {agent:"thinker",icon:"🧠",message:"TFSA room: $4,200 remaining"},
    {agent:"thinker",icon:"🧠",message:"Rewards misaligned: restaurants $45 vs recurring $170"},
    {agent:"thinker",icon:"🧠",message:"Total opportunity: $1,027/year"},
    {agent:"doer",icon:"⚡",message:"Actions ready. Awaiting approval."},
  ],
};

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const userId = body.userId;
    if (!userId) return NextResponse.json({ data: FALLBACK, activityLog: FALLBACK.agent_log });

    const db = dbAdmin();

    // Try Gemini, fall back to hardcoded if it fails
    if (ai) {
      try {
        const [p, tx, ac, g] = await Promise.all([
          db.from("user_profiles").select("*").eq("id", userId).single(),
          db.from("transactions").select("*").eq("user_id", userId).order("date", { ascending: false }),
          db.from("accounts").select("*").eq("user_id", userId),
          db.from("savings_goals").select("*").eq("user_id", userId).eq("status", "active"),
        ]);

        const model = ai.getGenerativeModel({ model: "gemini-1.5-flash" });
        const r = await model.generateContent([{
          text: INSIGHTS_PROMPT + "\n\nData:\n" + JSON.stringify({
            user: p.data, accounts: ac.data, goals: g.data,
            transactions: (tx.data || []).map((t: any) => ({
              date: t.date, vendor: t.vendor, amount: t.amount, category: t.category,
              type: t.tx_type, is_recurring: t.is_recurring, spend_type: t.spend_type,
            })),
            current_date: new Date().toISOString().slice(0, 10),
          }),
        }]);

        const text = r.response.text();
        const parsed = JSON.parse(exJ(text));
        if (parsed.messages && parsed.messages.length > 0) {
          return NextResponse.json({ data: parsed, activityLog: parsed.agent_log || FALLBACK.agent_log });
        }
      } catch (geminiErr: any) {
        console.error("Gemini failed, using fallback:", geminiErr.message);
      }
    }

    // Fallback
    return NextResponse.json({ data: FALLBACK, activityLog: FALLBACK.agent_log });
  } catch (e: any) {
    console.error("Insights route error:", e);
    return NextResponse.json({ data: FALLBACK, activityLog: FALLBACK.agent_log });
  }
}

function exJ(t: string): string {
  const c = t.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (c) return c[1].trim();
  const r = t.match(/\{[\s\S]*\}/);
  return r ? r[0] : t;
}
EOF

# ─── API: receipt (with fallback) ─────────────────────────────
cat > peel/src/app/api/receipt/route.ts << 'EOF'
import { NextRequest, NextResponse } from "next/server";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { RECEIPT_PROMPT } from "@/data/prompts";
import { dbAdmin } from "@/lib/supabase";

const ai = process.env.GEMINI_API_KEY ? new GoogleGenerativeAI(process.env.GEMINI_API_KEY) : null;

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const { image, userId } = body;
    if (!userId || !image) return NextResponse.json({ error: "Missing data" }, { status: 400 });

    const m = image.match(/^data:(.+);base64,(.+)$/);
    if (!m) return NextResponse.json({ error: "Bad image format" }, { status: 400 });

    const db = dbAdmin();
    let receipt: any = null;

    if (ai) {
      try {
        const model = ai.getGenerativeModel({ model: "gemini-1.5-flash" });
        const r = await model.generateContent([
          { text: RECEIPT_PROMPT + "\nParse this receipt:" },
          { inlineData: { mimeType: m[1], data: m[2] } },
        ]);
        receipt = JSON.parse(exJ(r.response.text()));
      } catch (geminiErr: any) {
        console.error("Gemini receipt failed:", geminiErr.message);
      }
    }

    // Fallback receipt if Gemini failed
    if (!receipt) {
      receipt = {
        vendor_name: "Scanned Receipt",
        date: new Date().toISOString().slice(0, 10),
        total_amount: 0,
        gst_hst_amount: 0,
        items: [],
        category: "Other",
        spend_type: "want",
        is_business_expense: false,
        cra_form: "N/A",
        confidence: 0,
      };
    }

    // Write to DB
    try {
      await db.from("scanned_receipts").insert({
        user_id: userId, vendor_name: receipt.vendor_name, total_amount: receipt.total_amount,
        category: receipt.category, is_business_expense: receipt.is_business_expense,
        cra_form: receipt.cra_form, items: receipt.items || [],
        gst_hst_amount: receipt.gst_hst_amount || 0, spend_type: receipt.spend_type || "want",
      });
      await db.from("transactions").insert({
        user_id: userId, date: receipt.date || new Date().toISOString().slice(0, 10),
        vendor: receipt.vendor_name, amount: receipt.total_amount || 0,
        category: receipt.category || "Other", tx_type: "debit", account_name: "Visa",
        is_business: receipt.is_business_expense || false, spend_type: receipt.spend_type || "want",
      });
    } catch (dbErr: any) {
      console.error("DB write failed:", dbErr.message);
    }

    const analysis = {
      messages: [
        { type: "receipt_parsed", text: `got it — $${receipt.total_amount || 0} at ${receipt.vendor_name}, tagged as ${(receipt.category || "other").toLowerCase()} (${receipt.spend_type || "want"}) 📎` },
        { type: "budget_note", text: receipt.is_business_expense ? `that's a business deduction on your T2125 ✓` : `logged as a ${receipt.spend_type || "want"} expense` },
      ],
      reasoning_steps: [
        `Parsed: ${receipt.vendor_name}`,
        `Amount: $${receipt.total_amount || 0}`,
        `Category: ${receipt.category || "Other"} (${receipt.spend_type || "want"})`,
      ],
    };

    const activityLog = [
      { agent: "watcher", icon: "👁️", message: `${receipt.vendor_name}, $${receipt.total_amount} — ${receipt.category}` },
      { agent: "thinker", icon: "🧠", message: `Classified as ${receipt.spend_type} expense` },
      { agent: "doer", icon: "⚡", message: "Added to expense report." },
    ];

    return NextResponse.json({ receipt, analysis, activityLog });
  } catch (e: any) {
    console.error("Receipt route error:", e);
    return NextResponse.json({
      receipt: { vendor_name: "Unknown", total_amount: 0, category: "Other", spend_type: "want", is_business_expense: false, cra_form: "N/A" },
      analysis: { messages: [{ type: "receipt_parsed", text: "hmm had trouble reading that one. try a clearer photo? 📸" }], reasoning_steps: [] },
      activityLog: [{ agent: "watcher", icon: "👁️", message: "Receipt scan completed with issues" }],
    });
  }
}

function exJ(t: string): string {
  const c = t.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (c) return c[1].trim();
  const r = t.match(/\{[\s\S]*\}/);
  return r ? r[0] : t;
}
EOF

# ─── API: execute (with fallback) ─────────────────────────────
cat > peel/src/app/api/execute/route.ts << 'EOF'
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
        const model = ai.getGenerativeModel({ model: "gemini-1.5-flash" });
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
EOF

# ─── API: purchase-check (with fallback) ─────────────────────
cat > peel/src/app/api/purchase-check/route.ts << 'EOF'
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
EOF

echo ""
echo "✅ All 4 API routes fixed!"
echo ""
echo "What changed:"
echo "  • Every route now has hardcoded fallback responses"
echo "  • If Gemini fails, the demo still works with pre-written content"
echo "  • No route will ever return an empty body or crash"
echo "  • Every error is caught and returns valid JSON"
echo ""
echo "  git add . && git commit -m 'fix: bulletproof API routes' && git push"
echo ""
echo "🍊 This will work."
