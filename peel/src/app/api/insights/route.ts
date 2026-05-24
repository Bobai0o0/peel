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
