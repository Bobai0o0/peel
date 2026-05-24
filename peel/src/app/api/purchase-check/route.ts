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
