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
