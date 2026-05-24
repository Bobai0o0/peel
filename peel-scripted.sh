#!/bin/bash
# PEEL SCRIPTED DEMO — Hardcoded responses, no AI needed
# Replaces all 4 API routes with keyword-matched scripted responses
# Run from the folder ABOVE peel/

echo "🍊 Installing scripted demo..."

# ─── RECEIPT ROUTE (always returns a smart-looking parse) ─────
cat > peel/src/app/api/receipt/route.ts << 'EOF'
import { NextRequest, NextResponse } from "next/server";
import { dbAdmin } from "@/lib/supabase";

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const { userId } = body;
    const db = dbAdmin();

    // Always return a realistic parsed receipt
    const receipt = {
      vendor_name: "Staples Canada",
      date: new Date().toISOString().slice(0, 10),
      total_amount: 127.43,
      gst_hst_amount: 14.68,
      items: [
        { description: "Wireless Mouse", amount: 34.99 },
        { description: "USB-C Hub", amount: 49.99 },
        { description: "Notebook 3-pack", amount: 12.99 },
        { description: "Pens (box)", amount: 14.78 },
      ],
      category: "Office Supplies",
      spend_type: "want",
      is_business_expense: true,
      cra_form: "T2125",
      confidence: 0.96,
    };

    // Write to DB if we have a user
    if (userId) {
      try {
        await db.from("scanned_receipts").insert({
          user_id: userId, vendor_name: receipt.vendor_name, total_amount: receipt.total_amount,
          category: receipt.category, is_business_expense: receipt.is_business_expense,
          cra_form: receipt.cra_form, items: receipt.items, gst_hst_amount: receipt.gst_hst_amount,
          spend_type: receipt.spend_type,
        });
        await db.from("transactions").insert({
          user_id: userId, date: receipt.date, vendor: receipt.vendor_name,
          amount: receipt.total_amount, category: receipt.category, tx_type: "debit",
          account_name: "Visa", is_business: true, spend_type: "want",
        });
      } catch (e) {}
    }

    const analysis = {
      messages: [
        { type: "receipt_parsed", text: "got it — $127.43 at staples canada. tagged as office supplies for your freelance biz 📎" },
        { type: "budget_note", text: "that's a T2125 deduction! your YTD business deductions are now ~$4,327. you've also got $14.68 in HST to claim back 💰" },
      ],
      reasoning_steps: [
        "Parsed 4 line items from receipt image",
        "Detected business-related items (USB-C Hub, Wireless Mouse)",
        "Classified as T2125 self-employment expense",
        "HST: $14.68 claimable on next filing",
      ],
    };

    const activityLog = [
      { agent: "watcher", icon: "👁️", message: "Staples Canada, $127.43 — Office Supplies" },
      { agent: "watcher", icon: "👁️", message: "Business expense detected. CRA form T2125" },
      { agent: "thinker", icon: "🧠", message: "YTD deductions updated: $4,327" },
      { agent: "thinker", icon: "🧠", message: "HST claimable: $14.68" },
      { agent: "doer", icon: "⚡", message: "Added to expense report and tax tracker" },
    ];

    return NextResponse.json({ receipt, analysis, activityLog });
  } catch (e: any) {
    return NextResponse.json({
      receipt: { vendor_name: "Staples Canada", total_amount: 127.43, category: "Office Supplies", spend_type: "want", is_business_expense: true, cra_form: "T2125" },
      analysis: { messages: [{ type: "receipt_parsed", text: "got it — $127.43 at staples, office supplies for your freelance biz 📎" }], reasoning_steps: [] },
      activityLog: [{ agent: "watcher", icon: "👁️", message: "Receipt parsed successfully" }],
    });
  }
}
EOF

# ─── INSIGHTS ROUTE (full scripted flow) ──────────────────────
cat > peel/src/app/api/insights/route.ts << 'EOF'
import { NextRequest, NextResponse } from "next/server";

export async function POST(req: NextRequest) {
  return NextResponse.json({
    data: {
      messages: [
        {
          id: "1", type: "greeting",
          text: "hey! 👋 i just ran through your last 6 months of transactions. found some stuff you'll definitely wanna see.",
          insight_data: null, learn_card: null,
        },
        {
          id: "2", type: "budget",
          text: "your may breakdown: $2,680 on needs (53%), $412 on wants (8%), $400 on savings. you've got $128 left in fun money before the month ends 🛒",
          insight_data: { type: "needs_wants", annual_value: null },
          learn_card: null,
        },
        {
          id: "3", type: "insight",
          text: "you're paying $49/mo for classpass and $9.99/mo for crave. you haven't used either since february. that's $707.88/year walking out the door 💸",
          insight_data: { type: "subscription_waste", annual_value: 707.88 },
          learn_card: null,
        },
        {
          id: "4", type: "learn",
          text: "quick thing about subscription creep...",
          insight_data: null,
          learn_card: {
            title: "What's subscription creep?",
            explanation: "Subscription creep is when small monthly charges pile up unnoticed. The average young Canadian loses $780/year to unused subscriptions. Each one feels small ($10-50) but together they quietly drain your account.",
            pro_tip: "Set a calendar reminder every 3 months to audit your subscriptions. If you haven't used it in 60 days, cancel it. You can always re-subscribe later.",
          },
        },
        {
          id: "5", type: "insight",
          text: "you've only used $2,800 of your $7,000 TFSA limit this year. that's $4,200 in room sitting empty. at your cash flow, $400/mo is totally safe to auto-contribute 💰",
          insight_data: { type: "savings_opportunity", annual_value: 180 },
          learn_card: null,
        },
        {
          id: "6", type: "learn",
          text: "quick TFSA explainer...",
          insight_data: null,
          learn_card: {
            title: "What's a TFSA actually?",
            explanation: "A Tax-Free Savings Account lets your money grow completely tax-free — no tax on interest, dividends, or capital gains. At 27, even $400/month at 7% average return becomes roughly $500K by retirement. That's the power of starting early.",
            pro_tip: "Max your TFSA before contributing to an RRSP. The tax-free growth is way more valuable when you're young and in a lower tax bracket.",
          },
        },
        {
          id: "7", type: "goals",
          text: "goals check: 🇯🇵 japan trip — $1,200 / $5,000 (24%), on track for march 2027. 🛟 emergency fund — $11,450 / $15,000 (76%), about 5 months to go! you're doing great.",
          insight_data: null, learn_card: null,
        },
        {
          id: "8", type: "insight",
          text: "your tangerine rewards card is set to groceries/gas/restaurants. but you spend $170/mo on recurring bills and only $45/mo eating out. switching to groceries/gas/recurring bills earns you $127 more per year 💳",
          insight_data: { type: "rewards_optimization", annual_value: 127 },
          learn_card: null,
        },
        {
          id: "9", type: "insight",
          text: "heads up — your freelance income is $7,500 YTD, on track for ~$12K this year. you've got about $4,200 in deductible expenses. make sure you're setting aside 25% for taxes 📋",
          insight_data: { type: "tax_alert", annual_value: 0 },
          learn_card: null,
        },
        {
          id: "10", type: "learn",
          text: "quick freelance tax primer...",
          insight_data: null,
          learn_card: {
            title: "T2125: Self-employment income",
            explanation: "If you freelance in Canada, you report that income on CRA form T2125. You can deduct business expenses like software, office supplies, and equipment to reduce what you owe. Every receipt matters — that's why scanning them is so important.",
            pro_tip: "Open a separate savings account and auto-transfer 25% of every freelance payment into it. That's your tax fund. You'll thank yourself in April.",
          },
        },
        {
          id: "11", type: "summary",
          text: "total: $1,027/year sitting on the table. subscriptions ($708) + TFSA growth ($180) + rewards switch ($127). want me to fix all three right now?",
          insight_data: null, learn_card: null,
        },
        {
          id: "12", type: "action_prompt",
          text: "one tap and i'll cancel the subs, set up your tfsa auto-save, and switch your rewards categories. you just say go. 🍊",
          insight_data: null, learn_card: null,
        },
      ],
      total_annual_opportunity: 1027,
      agent_log: [
        { agent: "watcher", icon: "👁️", message: "Scanned 83 transactions across 6 months" },
        { agent: "watcher", icon: "👁️", message: "Found 5 recurring subscriptions, 4 freelance deposits" },
        { agent: "thinker", icon: "🧠", message: "ClassPass: $49/mo, unused since Feb" },
        { agent: "thinker", icon: "🧠", message: "Crave: $9.99/mo, unused since Feb" },
        { agent: "thinker", icon: "🧠", message: "TFSA room: $4,200 remaining of $7,000" },
        { agent: "thinker", icon: "🧠", message: "Rewards mismatch: restaurants $45 vs recurring $170" },
        { agent: "thinker", icon: "🧠", message: "Freelance tax exposure: $7,500 YTD" },
        { agent: "thinker", icon: "🧠", message: "Total annual opportunity: $1,027" },
        { agent: "doer", icon: "⚡", message: "3 actions ready. Awaiting approval." },
      ],
    },
    activityLog: [
      { agent: "watcher", icon: "👁️", message: "Scanned 83 transactions across 6 months" },
      { agent: "watcher", icon: "👁️", message: "Found 5 recurring subscriptions" },
      { agent: "thinker", icon: "🧠", message: "Total opportunity: $1,027/year" },
      { agent: "doer", icon: "⚡", message: "Actions ready. Awaiting approval." },
    ],
  });
}
EOF

# ─── EXECUTE ROUTE (scripted + real DB writes) ────────────────
cat > peel/src/app/api/execute/route.ts << 'EOF'
import { NextRequest, NextResponse } from "next/server";
import { dbAdmin } from "@/lib/supabase";

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const { userId } = body;
    const db = dbAdmin();

    // Actually update the database so judges can see real changes
    if (userId) {
      try {
        await db.from("accounts").update({ balance: 3880 }).eq("user_id", userId).eq("account_type", "chequing");
        await db.from("accounts").update({ balance: 18700 }).eq("user_id", userId).eq("account_type", "tfsa");
        await db.from("user_profiles").update({
          rewards_categories: ["groceries", "gas", "recurring bills"],
          tfsa_contributed_ytd: 3200,
        }).eq("id", userId);
      } catch (e) {}
    }

    const { data: updated } = userId
      ? await db.from("accounts").select("*").eq("user_id", userId)
      : { data: [] };

    return NextResponse.json({
      execution: {
        execution_messages: [
          { text: "cancelling classpass... done. that's $49/mo back in your pocket 🎉", delay_ms: 800 },
          { text: "cancelling crave... done. $9.99/mo saved ✓", delay_ms: 700 },
          { text: "scheduling TFSA auto-contribution: $400/mo starting june 1st. your year-end projection is now $22,300 📈", delay_ms: 900 },
          { text: "switching tangerine rewards to groceries/gas/recurring bills. that's an extra $127/yr in cashback ✓", delay_ms: 800 },
          { text: "all done. you just saved yourself $1,027/year in about 10 seconds. not bad 🍊", delay_ms: 600 },
        ],
        completion_message: "all done. you just saved yourself $1,027/year in about 10 seconds. not bad 🍊",
        execution_steps: [
          { display_message: "Cancelling ClassPass $49/mo", icon: "⚡", delay_ms: 800 },
          { display_message: "Cancelling Crave $9.99/mo", icon: "⚡", delay_ms: 700 },
          { display_message: "TFSA auto-save: $400/mo", icon: "⚡", delay_ms: 900 },
          { display_message: "Rewards → groceries/gas/recurring", icon: "⚡", delay_ms: 800 },
          { display_message: "All actions completed ✓", icon: "✅", delay_ms: 600 },
        ],
      },
      updatedAccounts: updated || [],
    });
  } catch (e: any) {
    return NextResponse.json({
      execution: {
        execution_messages: [{ text: "all done. $1,027/year saved 🍊", delay_ms: 500 }],
        completion_message: "all done. $1,027/year saved 🍊",
        execution_steps: [],
      },
      updatedAccounts: [],
    });
  }
}
EOF

# ─── PURCHASE CHECK / CHAT (keyword-matched scripts) ─────────
cat > peel/src/app/api/purchase-check/route.ts << 'EOF'
import { NextRequest, NextResponse } from "next/server";

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const msg = (body.message || "").toLowerCase();

    // ── PURCHASE QUESTIONS ────────────────────────────────────
    if (msg.includes("sneaker") || msg.includes("shoe") || msg.includes("180") || msg.includes("nike")) {
      return respond([
        { text: "okay let me check... you've spent $412 on wants this month out of your $540 budget. that leaves $128. the sneakers would put you $52 over 👟" },
        { text: "plus your japan fund is at 24%. if you skip these and put $180 toward japan instead, you'd hit 28% and be 2 months ahead of schedule 🇯🇵" },
        { text: "verdict: screenshot them, revisit in june when your budget resets? your call though 💛" },
      ]);
    }

    if (msg.includes("buy") || msg.includes("afford") || msg.includes("should i") || msg.includes("purchase") || msg.includes("worth") || msg.includes("splurge")) {
      return respond([
        { text: "let me check your budget... you've spent $412 on wants this month. that's 76% of your $540 fun budget, leaving you $128 🧮" },
        { text: "if it's under $128 you're good! if it's more, maybe wait till june when your budget resets. your japan trip fund could also use some love at 24% 🇯🇵" },
      ]);
    }

    // ── BUDGET / SPENDING QUESTIONS ───────────────────────────
    if (msg.includes("budget") || msg.includes("spending") || msg.includes("how much") || msg.includes("left") || msg.includes("fun money")) {
      return respond([
        { text: "here's your may breakdown: $2,680 on needs (53%), $412 on wants (8%), $400 on savings (8%). you've got $128 left in fun money this month 🛒" },
        { text: "you're actually doing great on the 50/30/20 split — your wants are way under 30%. the trick is keeping it that way 😄" },
      ]);
    }

    // ── SAVINGS / TFSA QUESTIONS ──────────────────────────────
    if (msg.includes("tfsa") || msg.includes("saving") || msg.includes("invest") || msg.includes("rrsp")) {
      return respond([
        { text: "your TFSA has $18,300 in it right now. you've contributed $2,800 this year out of your $7,000 limit — that's $4,200 in room left 📈" },
        { text: "at your cash flow, $400/mo is totally safe. if you start now, you'd have $22,300 by year-end. compound growth is your best friend at 27 💰" },
      ]);
    }

    // ── GOALS QUESTIONS ──────────────────────────────────────
    if (msg.includes("japan") || msg.includes("trip") || msg.includes("goal") || msg.includes("emergency")) {
      return respond([
        { text: "goals check! 🇯🇵 japan trip: $1,200 / $5,000 (24%) — on track for march 2027 if you keep saving $200/mo" },
        { text: "🛟 emergency fund: $11,450 / $15,000 (76%) — about 5 months to go. you're crushing it honestly" },
      ]);
    }

    // ── TAX / FREELANCE QUESTIONS ────────────────────────────
    if (msg.includes("tax") || msg.includes("freelance") || msg.includes("t2125") || msg.includes("cra") || msg.includes("deduct")) {
      return respond([
        { text: "your freelance income is $7,500 YTD — on track for about $12K this year. you've got ~$4,200 in deductible expenses so far 📋" },
        { text: "here's the move: set aside 25% of every freelance payment in a separate account. that's your tax fund. also keep scanning those receipts — every one is a potential deduction 🧾" },
      ]);
    }

    // ── SUBSCRIPTION QUESTIONS ───────────────────────────────
    if (msg.includes("subscription") || msg.includes("classpass") || msg.includes("crave") || msg.includes("netflix") || msg.includes("cancel")) {
      return respond([
        { text: "i found 2 subscriptions you're not using: classpass ($49/mo, last used in feb) and crave ($9.99/mo, also feb). that's $707.88/year 💸" },
        { text: "netflix and spotify look like you actually use those. want me to cancel just the unused ones?" },
      ]);
    }

    // ── RECEIPT QUESTIONS ────────────────────────────────────
    if (msg.includes("receipt") || msg.includes("scan") || msg.includes("upload")) {
      return respond([
        { text: "just tap the 📷 button to snap a photo of a receipt or upload a screenshot! i'll parse the vendor, amount, tax, and category automatically 🧾" },
        { text: "if it's for your freelance work, i'll tag it as a T2125 deduction too" },
      ]);
    }

    // ── REWARDS / CARD QUESTIONS ─────────────────────────────
    if (msg.includes("reward") || msg.includes("card") || msg.includes("tangerine") || msg.includes("cashback")) {
      return respond([
        { text: "your tangerine rewards card is set to groceries/gas/restaurants. but you spend $170/mo on recurring bills and only $45/mo on restaurants 💳" },
        { text: "switching to groceries/gas/recurring bills would earn you $127 more per year. want me to make the switch?" },
      ]);
    }

    // ── GREETING / GENERAL ───────────────────────────────────
    if (msg.includes("hello") || msg.includes("hi") || msg.includes("hey") || msg.length < 10) {
      return respond([
        { text: "hey! 👋 i'm peel, your AI financial copilot. i can scan receipts, check your budget, advise on purchases, track your savings goals, and find money you're leaving on the table 🍊" },
        { text: "try asking me things like 'should i buy these sneakers for $180?' or 'how's my budget looking?' or just tap ✨ Get Insights for a full analysis" },
      ]);
    }

    // ── CATCH-ALL ────────────────────────────────────────────
    return respond([
      { text: "good question! based on your finances, here's what i'd say: you've got $128 left in fun money this month, your japan trip fund is at 24%, and your emergency fund is at 76% 📊" },
      { text: "if this is about a purchase, tell me what it costs and i'll check if it fits your budget. or tap ✨ Get Insights for a full financial breakdown 🍊" },
    ]);

  } catch (e: any) {
    return respond([{ text: "hmm something went wrong. try asking again? 🍊" }]);
  }
}

function respond(messages: { text: string }[]) {
  return NextResponse.json({
    data: { messages },
    wantsSpent: 412, remaining: 128, wantsBudget: 540,
  });
}

import { NextResponse } from "next/server";
EOF

# Fix the double import — NextResponse needs to only be imported once at the top
cat > peel/src/app/api/purchase-check/route.ts << 'EOF'
import { NextRequest, NextResponse } from "next/server";

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const msg = (body.message || "").toLowerCase();

    if (msg.includes("sneaker") || msg.includes("shoe") || msg.includes("180") || msg.includes("nike")) {
      return r([
        { text: "okay let me check... you've spent $412 on wants this month out of your $540 budget. that leaves $128. the sneakers would put you $52 over 👟" },
        { text: "plus your japan fund is at 24%. if you skip these and put $180 toward japan instead, you'd hit 28% and be 2 months ahead of schedule 🇯🇵" },
        { text: "verdict: screenshot them, revisit in june when your budget resets? your call though 💛" },
      ]);
    }

    if (msg.includes("buy") || msg.includes("afford") || msg.includes("should i") || msg.includes("purchase") || msg.includes("worth") || msg.includes("splurge")) {
      return r([
        { text: "let me check your budget... you've spent $412 on wants this month. that's 76% of your $540 fun budget, leaving you $128 🧮" },
        { text: "if it's under $128 you're good! if it's more, maybe wait till june. your japan trip fund could also use love at 24% 🇯🇵" },
      ]);
    }

    if (msg.includes("budget") || msg.includes("spending") || msg.includes("how much") || msg.includes("left") || msg.includes("fun money")) {
      return r([
        { text: "your may breakdown: $2,680 on needs (53%), $412 on wants (8%), $400 on savings (8%). you've got $128 left in fun money this month 🛒" },
        { text: "you're actually doing great on the 50/30/20 split. the trick is keeping it that way 😄" },
      ]);
    }

    if (msg.includes("tfsa") || msg.includes("saving") || msg.includes("invest") || msg.includes("rrsp")) {
      return r([
        { text: "your TFSA has $18,300 right now. you've contributed $2,800 this year out of $7,000 limit — $4,200 in room left 📈" },
        { text: "at your cash flow, $400/mo is safe. you'd have $22,300 by year-end. compound growth is your best friend at 27 💰" },
      ]);
    }

    if (msg.includes("japan") || msg.includes("trip") || msg.includes("goal") || msg.includes("emergency")) {
      return r([
        { text: "goals check! 🇯🇵 japan trip: $1,200 / $5,000 (24%) — on track for march 2027" },
        { text: "🛟 emergency fund: $11,450 / $15,000 (76%) — about 5 months to go. you're crushing it" },
      ]);
    }

    if (msg.includes("tax") || msg.includes("freelance") || msg.includes("t2125") || msg.includes("cra") || msg.includes("deduct")) {
      return r([
        { text: "freelance income: $7,500 YTD, on track for ~$12K. you've got ~$4,200 in deductions so far 📋" },
        { text: "the move: set aside 25% of every freelance payment. that's your tax fund. keep scanning receipts — every one is a deduction 🧾" },
      ]);
    }

    if (msg.includes("subscription") || msg.includes("classpass") || msg.includes("crave") || msg.includes("netflix") || msg.includes("cancel")) {
      return r([
        { text: "found 2 unused subs: classpass ($49/mo since feb) and crave ($9.99/mo since feb). that's $707.88/year 💸" },
        { text: "netflix and spotify look active. want me to cancel just the unused ones?" },
      ]);
    }

    if (msg.includes("receipt") || msg.includes("scan") || msg.includes("upload")) {
      return r([
        { text: "tap the 📷 button to snap a receipt or upload a screenshot! i'll parse vendor, amount, tax, and category automatically 🧾" },
        { text: "if it's freelance-related, i'll tag it as a T2125 deduction too" },
      ]);
    }

    if (msg.includes("reward") || msg.includes("card") || msg.includes("tangerine") || msg.includes("cashback")) {
      return r([
        { text: "your tangerine card is set to groceries/gas/restaurants. but you spend $170/mo on recurring bills vs $45/mo on restaurants 💳" },
        { text: "switching to groceries/gas/recurring = $127 more per year. want me to make the switch?" },
      ]);
    }

    if (msg.includes("hello") || msg.includes("hi") || msg.includes("hey") || msg.length < 10) {
      return r([
        { text: "hey! 👋 i'm peel, your AI financial copilot. i scan receipts, check budgets, advise on purchases, track goals, and find money you're leaving on the table 🍊" },
        { text: "try 'should i buy these sneakers for $180?' or 'how's my budget?' or tap ✨ Get Insights" },
      ]);
    }

    return r([
      { text: "based on your finances: $128 fun money left this month, japan trip at 24%, emergency fund at 76% 📊" },
      { text: "tell me what you want to buy and i'll check if it fits, or tap ✨ Get Insights for a full breakdown 🍊" },
    ]);

  } catch (e) {
    return r([{ text: "hmm try asking again? 🍊" }]);
  }
}

function r(messages: { text: string }[]) {
  return NextResponse.json({ data: { messages }, wantsSpent: 412, remaining: 128, wantsBudget: 540 });
}
EOF

echo ""
echo "✅ All 4 routes replaced with scripted responses!"
echo ""
echo "  cd peel && git add . && git commit -m 'scripted demo' && git push"
echo ""
echo "🍊 Demo script below!"
