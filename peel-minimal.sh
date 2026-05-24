#!/bin/bash
# PEEL MINIMAL — One script, all files, no extras
# Run: bash peel-minimal.sh

mkdir -p peel/src/app/api/receipt peel/src/app/api/insights peel/src/app/api/execute peel/src/app/api/purchase-check peel/src/app/api/seed-demo peel/src/lib peel/src/data peel/supabase

cat > peel/.gitignore << 'EOF'
node_modules
.next
.env.local
EOF

cat > peel/package.json << 'EOF'
{"name":"peel","private":true,"scripts":{"dev":"next dev","build":"next build"},"dependencies":{"next":"14.2.0","react":"18.3.1","react-dom":"18.3.1","@google/generative-ai":"0.14.1","@supabase/supabase-js":"2.43.4"},"devDependencies":{"typescript":"5.4.5","@types/react":"18.3.3","@types/node":"20.14.2"}}
EOF

cat > peel/tsconfig.json << 'EOF'
{"compilerOptions":{"target":"es5","lib":["dom","dom.iterable","esnext"],"allowJs":true,"skipLibCheck":true,"strict":false,"noEmit":true,"esModuleInterop":true,"module":"esnext","moduleResolution":"bundler","resolveJsonModule":true,"isolatedModules":true,"jsx":"preserve","incremental":true,"paths":{"@/*":["./src/*"]}},"include":["next-env.d.ts","**/*.ts","**/*.tsx"],"exclude":["node_modules"]}
EOF

cat > peel/next.config.js << 'EOF'
module.exports = {};
EOF

cat > peel/.env.local.example << 'EOF'
GEMINI_API_KEY=
NEXT_PUBLIC_SUPABASE_URL=
NEXT_PUBLIC_SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
EOF

# ─── SCHEMA ───────────────────────────────────────────────────
cat > peel/supabase/schema.sql << 'EOF'
create table user_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null, salary numeric default 0, freelance_ytd numeric default 0,
  tfsa_contributed_ytd numeric default 0, tfsa_limit numeric default 7000,
  rewards_categories text[] default '{"groceries","gas","restaurants"}',
  monthly_wants_budget numeric default 1540,
  created_at timestamptz default now()
);

create table accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  name text not null, account_type text not null,
  balance numeric not null, institution text not null
);

create table transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  date date not null, vendor text not null, amount numeric not null,
  category text not null, tx_type text not null, account_name text not null,
  is_recurring boolean default false, is_business boolean default false,
  spend_type text default 'need'
);

create table scanned_receipts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  vendor_name text, total_amount numeric, category text,
  is_business_expense boolean default false, cra_form text,
  items jsonb default '[]', gst_hst_amount numeric,
  spend_type text default 'want',
  created_at timestamptz default now()
);

create table insights (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  insight_type text, headline text, detail text,
  annual_value numeric, status text default 'pending',
  created_at timestamptz default now()
);

create table agent_activity (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  agent text not null, icon text not null, message text not null,
  session_id text, created_at timestamptz default now()
);

create table savings_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  name text not null, target_amount numeric not null,
  current_amount numeric default 0, target_date date,
  status text default 'active'
);

create table purchase_checks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  item_description text, verdict text,
  monthly_spent_so_far numeric, monthly_remaining numeric,
  created_at timestamptz default now()
);

alter publication supabase_realtime add table accounts;
alter publication supabase_realtime add table agent_activity;
EOF

# ─── LIB ──────────────────────────────────────────────────────
cat > peel/src/lib/supabase.ts << 'EOF'
import { createClient } from "@supabase/supabase-js";
export const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);
export const dbAdmin = () => createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE_KEY!);
EOF

# ─── PROMPTS ──────────────────────────────────────────────────
cat > peel/src/data/prompts.ts << 'ENDPROMPTS'
export const RECEIPT_PROMPT = `You are Peel, a Canadian financial AI. Extract receipt data. Return ONLY JSON:
{"vendor_name":string,"date":"YYYY-MM-DD","total_amount":number,"gst_hst_amount":number,"items":[{"description":string,"amount":number}],"category":"Groceries"|"Office Supplies"|"Restaurants"|"Transportation"|"Shopping"|"Subscriptions"|"Other","spend_type":"need"|"want","is_business_expense":boolean,"cra_form":"T2125"|"N/A","confidence":number}
need=groceries,utilities,gas,pharmacy. want=restaurants,shopping,entertainment. Estimate Ontario 13% HST if not shown.`;

export const INSIGHTS_PROMPT = `You are Peel, a casual witty AI financial copilot texting a young Canadian. Analyze their data.
Return ONLY JSON:
{"messages":[{"id":string,"type":"greeting"|"insight"|"learn"|"budget"|"goals"|"summary"|"action_prompt","text":string,"insight_data":{"type":"subscription_waste"|"savings_opportunity"|"rewards_optimization"|"tax_alert"|null,"annual_value":number|null}|null,"learn_card":{"title":string,"explanation":string,"pro_tip":string}|null}],"total_annual_opportunity":number,"agent_log":[{"agent":string,"icon":string,"message":string}]}
Generate in order: 1.greeting 2.budget(needs vs wants this month, fun money left) 3.subscription_waste(unused subs, $amounts) 4.learn(subscription creep) 5.savings_opportunity(TFSA room) 6.learn(what TFSA is) 7.goals(progress) 8.rewards_optimization(card switch value) 9.tax_alert(freelance exposure) 10.summary(total $) 11.action_prompt(one tap CTA)
Tone: lowercase, iMessage, specific dollars, "here's the move" not "I recommend".`;

export const EXPENSE_PROMPT = `You are Peel analyzing a scanned receipt. Return ONLY JSON:
{"messages":[{"type":"receipt_parsed","text":string},{"type":"budget_note","text":string}],"reasoning_steps":[string]}
Casual lowercase, mention need vs want and remaining fun money.`;

export const DOER_PROMPT = `You are Peel executing financial actions. Return ONLY JSON:
{"execution_messages":[{"text":string,"delay_ms":number}],"completion_message":string,"execution_steps":[{"display_message":string,"icon":"⚡","delay_ms":number}]}
4-6 casual messages with specific dollars. Celebrate each action.`;

export const PURCHASE_PROMPT = `You are Peel, a financial bestie. Someone wants to buy something. Return ONLY JSON:
{"verdict":"go_for_it"|"maybe_wait"|"skip_it","messages":[{"text":string}]}
Never shame. Reference specific budget numbers and goals by name. 2-3 casual lowercase messages.`;
ENDPROMPTS

# ─── API: seed-demo ──────────────────────────────────────────
cat > peel/src/app/api/seed-demo/route.ts << 'EOF'
import { NextRequest, NextResponse } from "next/server";
import { dbAdmin } from "@/lib/supabase";
import { createClient } from "@supabase/supabase-js";

export async function POST(req: NextRequest) {
  const db = dbAdmin();
  const token = req.headers.get("authorization")?.replace("Bearer ", "");
  if (!token) return NextResponse.json({ error: "No auth" }, { status: 401 });
  const uc = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);
  const { data: { user } } = await uc.auth.getUser(token);
  if (!user) return NextResponse.json({ error: "Bad token" }, { status: 401 });
  const u = user.id;

  await db.from("savings_goals").delete().eq("user_id",u);
  await db.from("agent_activity").delete().eq("user_id",u);
  await db.from("insights").delete().eq("user_id",u);
  await db.from("scanned_receipts").delete().eq("user_id",u);
  await db.from("transactions").delete().eq("user_id",u);
  await db.from("accounts").delete().eq("user_id",u);
  await db.from("user_profiles").delete().eq("id",u);

  await db.from("user_profiles").insert({ id:u, name:user.user_metadata?.name||"Priya", salary:72000, freelance_ytd:7500, tfsa_contributed_ytd:2800, tfsa_limit:7000, rewards_categories:["groceries","gas","restaurants"], monthly_wants_budget:1540 });
  await db.from("accounts").insert([
    { user_id:u, name:"Chequing", account_type:"chequing", balance:4280, institution:"Tangerine" },
    { user_id:u, name:"Savings", account_type:"savings", balance:11450, institution:"Tangerine" },
    { user_id:u, name:"TFSA", account_type:"tfsa", balance:18300, institution:"Tangerine" },
    { user_id:u, name:"Visa Infinite", account_type:"credit", balance:-1870, institution:"TD" },
  ]);
  await db.from("savings_goals").insert([
    { user_id:u, name:"Japan Trip 🇯🇵", target_amount:5000, current_amount:1200, target_date:"2027-03-01" },
    { user_id:u, name:"Emergency Fund 🛟", target_amount:15000, current_amount:11450 },
  ]);

  const t=(d,v,a,c,ty,ac,r,b,s)=>({user_id:u,date:d,vendor:v,amount:a,category:c,tx_type:ty,account_name:ac,is_recurring:r,is_business:b,spend_type:s});
  const txns=[
    t("2025-12-01","Landlord",2100,"Rent","debit","Chequing",true,false,"need"),
    t("2025-12-03","Netflix",16.49,"Subscriptions","debit","Visa",true,false,"want"),
    t("2025-12-03","Spotify",11.99,"Subscriptions","debit","Visa",true,false,"want"),
    t("2025-12-03","ClassPass",49,"Subscriptions","debit","Visa",true,false,"want"),
    t("2025-12-03","Crave",9.99,"Subscriptions","debit","Visa",true,false,"want"),
    t("2025-12-05","PixelWorks",2500,"Freelance Income","credit","Chequing",false,true,"income"),
    t("2025-12-12","Shell",65,"Gas","debit","Visa",false,false,"need"),
    t("2025-12-15","TFSA",400,"Savings","debit","Chequing",false,false,"savings"),
    t("2025-12-20","Hydro One",78.43,"Utilities","debit","Chequing",true,false,"need"),
    t("2025-12-20","Rogers",85,"Phone","debit","Chequing",true,false,"need"),
    t("2026-01-01","Landlord",2100,"Rent","debit","Chequing",true,false,"need"),
    t("2026-01-03","Netflix",16.49,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-01-03","Spotify",11.99,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-01-03","ClassPass",49,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-01-03","Crave",9.99,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-01-10","PixelWorks",1800,"Freelance Income","credit","Chequing",false,true,"income"),
    t("2026-01-15","TFSA",400,"Savings","debit","Chequing",false,false,"savings"),
    t("2026-01-18","Shell",58.5,"Gas","debit","Visa",false,false,"need"),
    t("2026-01-20","Hydro One",82.1,"Utilities","debit","Chequing",true,false,"need"),
    t("2026-01-20","Rogers",85,"Phone","debit","Chequing",true,false,"need"),
    t("2026-02-01","Landlord",2100,"Rent","debit","Chequing",true,false,"need"),
    t("2026-02-03","Netflix",16.49,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-02-03","ClassPass",49,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-02-03","Crave",9.99,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-02-15","TFSA",400,"Savings","debit","Chequing",false,false,"savings"),
    t("2026-02-20","Hydro One",75.9,"Utilities","debit","Chequing",true,false,"need"),
    t("2026-02-20","Rogers",85,"Phone","debit","Chequing",true,false,"need"),
    t("2026-02-22","PixelWorks",3200,"Freelance Income","credit","Chequing",false,true,"income"),
    t("2026-03-01","Landlord",2100,"Rent","debit","Chequing",true,false,"need"),
    t("2026-03-03","Netflix",16.49,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-03-03","ClassPass",49,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-03-03","Crave",9.99,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-03-15","TFSA",400,"Savings","debit","Chequing",false,false,"savings"),
    t("2026-03-20","Hydro One",71.2,"Utilities","debit","Chequing",true,false,"need"),
    t("2026-03-20","Rogers",85,"Phone","debit","Chequing",true,false,"need"),
    t("2026-04-01","Landlord",2100,"Rent","debit","Chequing",true,false,"need"),
    t("2026-04-03","Netflix",16.49,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-04-03","ClassPass",49,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-04-03","Crave",9.99,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-04-15","TFSA",400,"Savings","debit","Chequing",false,false,"savings"),
    t("2026-04-20","Hydro One",68.5,"Utilities","debit","Chequing",true,false,"need"),
    t("2026-04-20","Rogers",85,"Phone","debit","Chequing",true,false,"need"),
    t("2026-05-01","Landlord",2100,"Rent","debit","Chequing",true,false,"need"),
    t("2026-05-03","Netflix",16.49,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-05-03","ClassPass",49,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-05-03","Crave",9.99,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-05-10","PixelWorks",1500,"Freelance Income","credit","Chequing",false,true,"income"),
    t("2026-05-15","TFSA",400,"Savings","debit","Chequing",false,false,"savings"),
    t("2026-05-20","Hydro One",74.8,"Utilities","debit","Chequing",true,false,"need"),
    t("2026-05-20","Rogers",85,"Phone","debit","Chequing",true,false,"need"),
  ];
  await db.from("transactions").insert(txns);
  return NextResponse.json({ ok:true, txns:txns.length });
}
EOF

# ─── API: receipt ─────────────────────────────────────────────
cat > peel/src/app/api/receipt/route.ts << 'EOF'
import { NextRequest, NextResponse } from "next/server";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { RECEIPT_PROMPT, EXPENSE_PROMPT } from "@/data/prompts";
import { dbAdmin } from "@/lib/supabase";
const ai = new GoogleGenerativeAI(process.env.GEMINI_API_KEY!);

export async function POST(req: NextRequest) {
  const db = dbAdmin();
  const { image, userId } = await req.json();
  if (!userId) return NextResponse.json({ error: "No user" }, { status: 400 });
  const m = image.match(/^data:(.+);base64,(.+)$/);
  if (!m) return NextResponse.json({ error: "Bad image" }, { status: 400 });

  const sid = crypto.randomUUID();
  const model = ai.getGenerativeModel({ model: "gemini-1.5-flash" });

  const r1 = await model.generateContent([{ text: RECEIPT_PROMPT + "\nParse:" }, { inlineData: { mimeType: m[1], data: m[2] } }]);
  const receipt = JSON.parse(exJ(r1.response.text()));

  await db.from("scanned_receipts").insert({ user_id:userId, vendor_name:receipt.vendor_name, total_amount:receipt.total_amount, category:receipt.category, is_business_expense:receipt.is_business_expense, cra_form:receipt.cra_form, items:receipt.items, gst_hst_amount:receipt.gst_hst_amount, spend_type:receipt.spend_type });
  await db.from("transactions").insert({ user_id:userId, date:receipt.date||new Date().toISOString().slice(0,10), vendor:receipt.vendor_name, amount:receipt.total_amount, category:receipt.category, tx_type:"debit", account_name:"Visa", is_business:receipt.is_business_expense, spend_type:receipt.spend_type||"want" });

  const log = [
    { agent:"watcher", icon:"👁️", message:`${receipt.vendor_name}, $${receipt.total_amount} — ${receipt.category}` },
    { agent:"watcher", icon:"👁️", message: receipt.is_business_expense ? `Business expense. ${receipt.cra_form}` : `${receipt.spend_type} expense` },
  ];

  const r2 = await model.generateContent([{ text: EXPENSE_PROMPT + "\n" + JSON.stringify({ expense:receipt, ytd_deductions:4200 }) }]);
  const analysis = JSON.parse(exJ(r2.response.text()));
  for (const s of analysis.reasoning_steps||[]) log.push({ agent:"thinker", icon:"🧠", message:s });
  log.push({ agent:"doer", icon:"⚡", message:"Added to expense report." });

  for (const l of log) await db.from("agent_activity").insert({ ...l, user_id:userId, session_id:sid });
  return NextResponse.json({ receipt, analysis, activityLog:log });
}
function exJ(t){const c=t.match(/```(?:json)?\s*([\s\S]*?)```/);if(c)return c[1].trim();const r=t.match(/\{[\s\S]*\}/);return r?r[0]:t}
EOF

# ─── API: insights ────────────────────────────────────────────
cat > peel/src/app/api/insights/route.ts << 'EOF'
import { NextRequest, NextResponse } from "next/server";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { INSIGHTS_PROMPT } from "@/data/prompts";
import { dbAdmin } from "@/lib/supabase";
const ai = new GoogleGenerativeAI(process.env.GEMINI_API_KEY!);

export async function POST(req: NextRequest) {
  const db = dbAdmin();
  const { userId } = await req.json();
  if (!userId) return NextResponse.json({ error: "No user" }, { status: 400 });
  const sid = crypto.randomUUID();

  const [p,tx,ac,g] = await Promise.all([
    db.from("user_profiles").select("*").eq("id",userId).single(),
    db.from("transactions").select("*").eq("user_id",userId).order("date",{ascending:false}),
    db.from("accounts").select("*").eq("user_id",userId),
    db.from("savings_goals").select("*").eq("user_id",userId).eq("status","active"),
  ]);

  const model = ai.getGenerativeModel({ model: "gemini-1.5-flash" });
  const r = await model.generateContent([{ text: INSIGHTS_PROMPT + "\n\nData:\n" + JSON.stringify({
    user:p.data, accounts:ac.data, goals:g.data,
    transactions:(tx.data||[]).map(t=>({date:t.date,vendor:t.vendor,amount:t.amount,category:t.category,type:t.tx_type,is_recurring:t.is_recurring,spend_type:t.spend_type})),
    current_date:new Date().toISOString().slice(0,10),
  })}]);

  const data = JSON.parse(exJ(r.response.text()));
  for (const e of data.agent_log||[]) await db.from("agent_activity").insert({...e,user_id:userId,session_id:sid});
  return NextResponse.json({ data, activityLog:data.agent_log||[] });
}
function exJ(t){const c=t.match(/```(?:json)?\s*([\s\S]*?)```/);if(c)return c[1].trim();const r=t.match(/\{[\s\S]*\}/);return r?r[0]:t}
EOF

# ─── API: execute ─────────────────────────────────────────────
cat > peel/src/app/api/execute/route.ts << 'EOF'
import { NextRequest, NextResponse } from "next/server";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { DOER_PROMPT } from "@/data/prompts";
import { dbAdmin } from "@/lib/supabase";
const ai = new GoogleGenerativeAI(process.env.GEMINI_API_KEY!);

export async function POST(req: NextRequest) {
  const db = dbAdmin();
  const { userId } = await req.json();
  if (!userId) return NextResponse.json({ error: "No user" }, { status: 400 });

  const model = ai.getGenerativeModel({ model: "gemini-1.5-flash" });
  const r = await model.generateContent([{ text: DOER_PROMPT + "\nActions: cancel ClassPass $49/mo + Crave $9.99/mo, schedule TFSA $400/mo, switch rewards to groceries/gas/recurring +$127/yr" }]);
  const exec = JSON.parse(exJ(r.response.text()));

  await db.from("accounts").update({balance:3880}).eq("user_id",userId).eq("account_type","chequing");
  await db.from("accounts").update({balance:18700}).eq("user_id",userId).eq("account_type","tfsa");
  await db.from("user_profiles").update({rewards_categories:["groceries","gas","recurring bills"],tfsa_contributed_ytd:3200}).eq("id",userId);
  await db.from("insights").update({status:"approved"}).eq("user_id",userId).eq("status","pending");

  const {data:updated} = await db.from("accounts").select("*").eq("user_id",userId);
  return NextResponse.json({ execution:exec, updatedAccounts:updated });
}
function exJ(t){const c=t.match(/```(?:json)?\s*([\s\S]*?)```/);if(c)return c[1].trim();const r=t.match(/\{[\s\S]*\}/);return r?r[0]:t}
EOF

# ─── API: purchase-check ─────────────────────────────────────
cat > peel/src/app/api/purchase-check/route.ts << 'EOF'
import { NextRequest, NextResponse } from "next/server";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { PURCHASE_PROMPT } from "@/data/prompts";
import { dbAdmin } from "@/lib/supabase";
const ai = new GoogleGenerativeAI(process.env.GEMINI_API_KEY!);

export async function POST(req: NextRequest) {
  const db = dbAdmin();
  const { message, userId } = await req.json();
  if (!userId) return NextResponse.json({ error: "No user" }, { status: 400 });

  const month = new Date().toISOString().slice(0,7)+"-01";
  const {data:w} = await db.from("transactions").select("amount").eq("user_id",userId).eq("spend_type","want").gte("date",month);
  const spent = (w||[]).reduce((s,t)=>s+Number(t.amount),0);
  const budget = 1540;
  const {data:goals} = await db.from("savings_goals").select("*").eq("user_id",userId).eq("status","active");

  const model = ai.getGenerativeModel({ model: "gemini-1.5-flash" });
  const r = await model.generateContent([{ text: PURCHASE_PROMPT + "\nUser: " + message + "\nBudget: " + JSON.stringify({wants_spent:spent,wants_budget:budget,remaining:budget-spent,goals:(goals||[]).map(g=>({name:g.name,target:g.target_amount,current:g.current_amount}))}) }]);
  const data = JSON.parse(exJ(r.response.text()));
  return NextResponse.json({ data, wantsSpent:spent, remaining:budget-spent, wantsBudget:budget });
}
function exJ(t){const c=t.match(/```(?:json)?\s*([\s\S]*?)```/);if(c)return c[1].trim();const r=t.match(/\{[\s\S]*\}/);return r?r[0]:t}
EOF

# ─── LAYOUT ───────────────────────────────────────────────────
cat > peel/src/app/layout.tsx << 'EOF'
import type { Metadata } from "next";
export const metadata: Metadata = { title: "Peel" };
export default function Layout({ children }: { children: React.ReactNode }) {
  return <html lang="en"><head><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1" /></head><body style={{background:"#0a0a0f",color:"#fff",fontFamily:"-apple-system,sans-serif",margin:0}}>{children}</body></html>;
}
EOF

# ─── PAGE (minimal, no tailwind, no framer-motion) ───────────
cat > peel/src/app/page.tsx << 'ENDPAGE'
"use client";
import { useState, useRef, useEffect, useCallback } from "react";
import { createClient } from "@supabase/supabase-js";

const sb = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);

export default function Home() {
  const [session, setSession] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [seeded, setSeeded] = useState(false);
  const [accounts, setAccounts] = useState<any[]>([]);
  const [msgs, setMsgs] = useState<{id:string;from:string;text:string;learnCard?:any;insightData?:any}[]>([]);
  const [typing, setTyping] = useState(false);
  const [input, setInput] = useState("");
  const [done, setDone] = useState(false);
  const [agentLog, setAgentLog] = useState<{agent:string;icon:string;message:string}[]>([]);
  const [showAgents, setShowAgents] = useState(false);
  const [receipt, setReceipt] = useState<any>(null);
  const endRef = useRef<HTMLDivElement>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    sb.auth.getSession().then(({data:{session:s}}) => { setSession(s); setLoading(false) });
    const {data:{subscription}} = sb.auth.onAuthStateChange((_,s) => setSession(s));
    return () => subscription.unsubscribe();
  }, []);

  useEffect(() => {
    if (!session || !seeded) return;
    const uid = session.user.id;
    sb.from("accounts").select("*").eq("user_id", uid).then(({data}) => { if(data) setAccounts(data) });
    const ch = sb.channel("a").on("postgres_changes",{event:"UPDATE",schema:"public",table:"accounts"},p=>{
      setAccounts(prev=>prev.map(a=>a.name===p.new.name?{...a,balance:p.new.balance}:a));
    }).subscribe();
    return ()=>{sb.removeChannel(ch)};
  }, [session, seeded]);

  useEffect(() => { endRef.current?.scrollIntoView({behavior:"smooth"}) }, [msgs, typing]);

  const uid = session?.user?.id;
  const name = session?.user?.email?.split("@")[0] || "there";

  const addPeel = useCallback(async (text:string, extra?:any) => {
    setTyping(true);
    await new Promise(r=>setTimeout(r,500+Math.random()*600));
    setTyping(false);
    setMsgs(p=>[...p,{id:crypto.randomUUID(),from:"peel",text,...extra}]);
  },[]);

  const seed = async () => {
    const res = await fetch("/api/seed-demo",{method:"POST",headers:{"Authorization":"Bearer "+session.access_token}});
    const d = await res.json();
    if (d.ok) setSeeded(true);
  };

  const scanReceipt = async (file:File) => {
    if(!uid) return;
    setMsgs(p=>[...p,{id:crypto.randomUUID(),from:"user",text:"📷 [receipt]"}]);
    setTyping(true);
    const reader = new FileReader();
    reader.onload = async () => {
      const res = await fetch("/api/receipt",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({image:reader.result,userId:uid})});
      const d = await res.json();
      setTyping(false);
      if(d.receipt) {
        setReceipt(d.receipt);
        setAgentLog(p=>[...p,...(d.activityLog||[])]);
        for(const m of d.analysis?.messages||[]) await addPeel(m.text);
        if(!d.analysis?.messages?.length) await addPeel(`got it — $${d.receipt.total_amount} at ${d.receipt.vendor_name}, ${d.receipt.category} (${d.receipt.spend_type})`);
      }
    };
    reader.readAsDataURL(file);
  };

  const getInsights = async () => {
    if(!uid) return;
    setMsgs(p=>[...p,{id:crypto.randomUUID(),from:"system",text:"analyzing..."}]);
    setTyping(true);
    const res = await fetch("/api/insights",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({userId:uid})});
    const d = await res.json();
    setTyping(false);
    setAgentLog(p=>[...p,...(d.activityLog||[])]);
    for(const m of d.data?.messages||[]) await addPeel(m.text,{learnCard:m.learn_card,insightData:m.insight_data});
  };

  const fixAll = async () => {
    if(!uid) return;
    setMsgs(p=>[...p,{id:crypto.randomUUID(),from:"user",text:"go 🚀"}]);
    setTyping(true);
    const res = await fetch("/api/execute",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({userId:uid})});
    const d = await res.json();
    setTyping(false);
    for(const m of d.execution?.execution_messages||[]) await addPeel(m.text);
    if(d.execution?.completion_message) await addPeel(d.execution.completion_message);
    if(d.updatedAccounts) setAccounts(d.updatedAccounts);
    setDone(true);
  };

  const checkPurchase = async (text:string) => {
    if(!uid) return;
    setMsgs(p=>[...p,{id:crypto.randomUUID(),from:"user",text}]);
    setTyping(true);
    const res = await fetch("/api/purchase-check",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({message:text,userId:uid})});
    const d = await res.json();
    setTyping(false);
    for(const m of d.data?.messages||[]) await addPeel(m.text);
  };

  const send = () => {
    if(!input.trim()) return;
    const t = input.trim(); setInput("");
    const l = t.toLowerCase();
    if(l.includes("buy")||l.includes("should i")||l.includes("afford")||l.includes("worth")||l.includes("splurge")) checkPurchase(t);
    else if(l.includes("insight")||l.includes("analyze")) getInsights();
    else checkPurchase(t);
  };

  // ─── STYLES ──────────────────────────────────────────────
  const S = {
    shell: {height:"100dvh",display:"flex",flexDirection:"column" as const,maxWidth:430,margin:"0 auto",overflow:"hidden"},
    header: {padding:"44px 16px 12px",display:"flex",justifyContent:"space-between",alignItems:"center",borderBottom:"1px solid rgba(255,255,255,0.06)"},
    logo: {display:"flex",alignItems:"center",gap:8},
    icon: {width:32,height:32,borderRadius:"50%",background:"linear-gradient(135deg,#FB923C,#EA580C)",display:"flex",alignItems:"center",justifyContent:"center",fontSize:14},
    brand: {fontWeight:800,fontSize:14,background:"linear-gradient(135deg,#F58220,#FF6B35)",WebkitBackgroundClip:"text",WebkitTextFillColor:"transparent"},
    scroll: {flex:1,overflowY:"auto" as const,padding:"0 0 100px"},
    card: {margin:"8px 16px",padding:14,background:"rgba(255,255,255,0.04)",borderRadius:16,border:"1px solid rgba(255,255,255,0.06)"},
    bubblePeel: {margin:"4px 16px",maxWidth:"85%",padding:"10px 14px",background:"rgba(255,255,255,0.07)",borderRadius:"18px 18px 18px 4px",fontSize:15,lineHeight:1.5,color:"#e5e5e5"},
    bubbleUser: {margin:"4px 16px",maxWidth:"80%",marginLeft:"auto",padding:"10px 14px",background:"#F58220",borderRadius:"18px 18px 4px 18px",fontSize:15,color:"#fff"},
    bubbleSys: {margin:"8px auto",fontSize:12,color:"#666",textAlign:"center" as const},
    learn: {margin:"2px 16px 2px 44px",padding:"8px 12px",background:"rgba(59,130,246,0.1)",border:"1px solid rgba(59,130,246,0.2)",borderRadius:12,fontSize:12,color:"#60a5fa",cursor:"pointer"},
    val: {display:"inline-block",marginTop:6,padding:"2px 8px",background:"rgba(245,130,32,0.15)",borderRadius:8,fontSize:12,fontWeight:700,color:"#FB923C"},
    input: {position:"fixed" as const,bottom:0,left:0,right:0,maxWidth:430,margin:"0 auto",padding:"12px",display:"flex",gap:8,background:"rgba(10,10,15,0.9)",borderTop:"1px solid rgba(255,255,255,0.06)",backdropFilter:"blur(20px)"},
    inputField: {flex:1,background:"rgba(255,255,255,0.04)",border:"1px solid rgba(255,255,255,0.06)",borderRadius:24,padding:"10px 16px",color:"#fff",fontSize:14,outline:"none"},
    btn: {padding:"10px 16px",background:"linear-gradient(135deg,#F58220,#EA580C)",border:"none",borderRadius:24,color:"#fff",fontWeight:600,fontSize:13,cursor:"pointer"},
    btnSm: {padding:"6px 12px",background:"rgba(255,255,255,0.04)",border:"1px solid rgba(255,255,255,0.06)",borderRadius:12,color:"#aaa",fontSize:12,cursor:"pointer"},
    fixBtn: {margin:"8px 16px",padding:"14px",background:"linear-gradient(135deg,#F58220,#EA580C)",border:"none",borderRadius:16,color:"#fff",fontWeight:700,fontSize:15,cursor:"pointer",width:"calc(100% - 32px)",textAlign:"center" as const},
    dots: {display:"flex",gap:4,padding:"12px 16px"},
    dot: {width:8,height:8,borderRadius:"50%",background:"#F58220",opacity:0.6},
    agentPanel: {position:"fixed" as const,bottom:0,left:0,right:0,maxWidth:430,margin:"0 auto",maxHeight:"40vh",background:"rgba(15,23,42,0.95)",borderTop:"1px solid rgba(255,255,255,0.1)",borderRadius:"16px 16px 0 0",overflow:"auto",padding:12,zIndex:50},
    agentEntry: {display:"flex",gap:8,marginBottom:8,fontSize:12,color:"#999"},
  };

  if(loading) return <div style={{...S.shell,justifyContent:"center",alignItems:"center"}}><p style={{color:"#666"}}>Loading...</p></div>;

  if(!session) return (
    <div style={{...S.shell,justifyContent:"center",alignItems:"center",padding:24}}>
      <div style={{...S.icon,width:64,height:64,fontSize:28,marginBottom:24}}>🍊</div>
      <h1 style={{...S.brand,fontSize:28,marginBottom:4}}>Peel</h1>
      <p style={{color:"#666",fontSize:14,marginBottom:32}}>AI financial copilot</p>
      <AuthForm/>
    </div>
  );

  if(!seeded) return (
    <div style={{...S.shell,justifyContent:"center",alignItems:"center",padding:24}}>
      <div style={{...S.icon,width:64,height:64,fontSize:28,marginBottom:24}}>🍊</div>
      <h1 style={{...S.brand,fontSize:22,marginBottom:8}}>Welcome to Peel</h1>
      <p style={{color:"#888",fontSize:14,marginBottom:24,textAlign:"center"}}>load demo data to get started</p>
      <button onClick={seed} style={S.btn}>Load demo data →</button>
      <button onClick={()=>sb.auth.signOut()} style={{...S.btnSm,marginTop:16}}>sign out</button>
    </div>
  );

  const total = accounts.reduce((s,a)=>s+a.balance,0);

  return (
    <div style={S.shell}>
      <div style={S.header}>
        <div style={S.logo}><div style={S.icon}>🍊</div><span style={S.brand}>Peel</span></div>
        <div style={{display:"flex",gap:8}}>
          <button onClick={()=>setShowAgents(!showAgents)} style={S.btnSm}>⚡ {agentLog.length}</button>
          <button onClick={()=>sb.auth.signOut()} style={S.btnSm}>logout</button>
        </div>
      </div>

      <div style={S.scroll}>
        {/* Accounts */}
        <div style={S.card}>
          <div style={{fontSize:11,color:"#888",textTransform:"uppercase",letterSpacing:1}}>Net Worth</div>
          <div style={{fontSize:28,fontWeight:900}}>${total.toLocaleString()}</div>
        </div>
        <div style={{display:"flex",gap:8,padding:"0 16px",overflowX:"auto"}}>
          {accounts.map((a,i)=><div key={i} style={{...S.card,margin:0,minWidth:130,flex:"0 0 auto"}}>
            <div style={{fontSize:11,color:"#888"}}>{a.name}</div>
            <div style={{fontSize:15,fontWeight:700,color:a.balance<0?"#f87171":"#fff"}}>${Math.abs(a.balance).toLocaleString()}</div>
            <div style={{fontSize:10,color:"#555"}}>{a.institution}</div>
          </div>)}
        </div>

        {/* Actions */}
        <div style={{display:"flex",gap:8,padding:"12px 16px"}}>
          <button onClick={()=>fileRef.current?.click()} style={{...S.btn,flex:1,fontSize:13}}>📷 Scan Receipt</button>
          <button onClick={getInsights} style={{...S.btn,flex:1,fontSize:13}}>✨ Get Insights</button>
        </div>

        {/* Receipt */}
        {receipt && <div style={S.card}>
          <div style={{display:"flex",justifyContent:"space-between"}}><b>{receipt.vendor_name}</b><span style={{color:"#FB923C",fontWeight:700}}>${receipt.total_amount}</span></div>
          <div style={{display:"flex",gap:4,marginTop:4}}>
            <span style={{padding:"2px 6px",background:"rgba(245,130,32,0.15)",borderRadius:6,fontSize:11,color:"#FB923C"}}>{receipt.category}</span>
            <span style={{padding:"2px 6px",background:"rgba(168,85,247,0.15)",borderRadius:6,fontSize:11,color:"#a855f7"}}>{receipt.spend_type}</span>
          </div>
        </div>}

        {/* Chat */}
        {msgs.map(m=>(
          <div key={m.id}>
            {m.from==="user"&&<div style={S.bubbleUser}>{m.text}</div>}
            {m.from==="system"&&<div style={S.bubbleSys}>{m.text}</div>}
            {m.from==="peel"&&<div style={{display:"flex",gap:8,padding:"4px 16px"}}>
              <div style={{...S.icon,width:28,height:28,fontSize:12,flexShrink:0}}>🍊</div>
              <div>
                <div style={S.bubblePeel}>{m.text}
                  {m.insightData?.annual_value>0&&<div style={S.val}>+${m.insightData.annual_value}/yr</div>}
                </div>
                {m.learnCard&&<LearnCard card={m.learnCard}/>}
              </div>
            </div>}
          </div>
        ))}

        {msgs.some(m=>m.text?.includes("say go"))&&!done&&<button onClick={fixAll} style={S.fixBtn}>⚡ Fix all three — save $1,027/yr</button>}
        {typing&&<div style={S.dots}><div style={{...S.dot,animation:"pulse 1.4s infinite"}}/><div style={{...S.dot,animation:"pulse 1.4s infinite .2s"}}/><div style={{...S.dot,animation:"pulse 1.4s infinite .4s"}}/></div>}
        <div ref={endRef}/>
      </div>

      <div style={S.input}>
        <button onClick={()=>fileRef.current?.click()} style={{...S.btnSm,padding:"10px 12px"}}>📷</button>
        <input value={input} onChange={e=>setInput(e.target.value)} onKeyDown={e=>e.key==="Enter"&&send()} placeholder="ask peel anything..." style={S.inputField}/>
        <button onClick={input.trim()?send:getInsights} style={{...S.btn,borderRadius:"50%",width:40,height:40,padding:0,display:"flex",alignItems:"center",justifyContent:"center"}}>{input.trim()?"→":"↑"}</button>
      </div>

      <input ref={fileRef} type="file" accept="image/*" className="hidden" style={{display:"none"}} onChange={e=>{const f=e.target.files?.[0];if(f)scanReceipt(f)}}/>

      {showAgents&&<div style={S.agentPanel}>
        <div style={{display:"flex",justifyContent:"space-between",marginBottom:8}}><b style={{fontSize:11,color:"#888",textTransform:"uppercase",letterSpacing:1}}>⚡ Agents</b><button onClick={()=>setShowAgents(false)} style={{background:"none",border:"none",color:"#666",cursor:"pointer"}}>✕</button></div>
        {agentLog.map((e,i)=><div key={i} style={S.agentEntry}><span>{e.icon}</span><div><div style={{fontSize:10,fontWeight:700,color:"#555",textTransform:"uppercase"}}>{e.agent}</div><div>{e.message}</div></div></div>)}
      </div>}

      <style>{`@keyframes pulse{0%,80%,100%{opacity:.3}40%{opacity:1}}`}</style>
    </div>
  );
}

function LearnCard({card}:{card:any}) {
  const [open,setOpen]=useState(false);
  return <div>
    <div onClick={()=>setOpen(!open)} style={{margin:"2px 0",padding:"6px 10px",background:"rgba(59,130,246,0.1)",border:"1px solid rgba(59,130,246,0.2)",borderRadius:10,fontSize:12,color:"#60a5fa",cursor:"pointer"}}>💡 {card.title} {open?"▲":"▼"}</div>
    {open&&<div style={{padding:"8px 10px",background:"rgba(255,255,255,0.03)",borderRadius:10,marginTop:2,fontSize:13,color:"#ccc",lineHeight:1.5}}>
      <p>{card.explanation}</p>
      <p style={{marginTop:6,padding:"6px 8px",background:"rgba(245,130,32,0.1)",borderRadius:8,fontSize:12,color:"#FB923C"}}>🎯 {card.pro_tip}</p>
    </div>}
  </div>;
}

function AuthForm() {
  const [email,setEmail]=useState("");
  const [pass,setPass]=useState("");
  const [mode,setMode]=useState<"login"|"signup">("signup");
  const [err,setErr]=useState("");
  const go = async () => {
    setErr("");
    const {error} = mode==="signup"
      ? await sb.auth.signUp({email,password:pass})
      : await sb.auth.signInWithPassword({email,password:pass});
    if(error) setErr(error.message);
  };
  return <div style={{width:"100%",maxWidth:320}}>
    <input value={email} onChange={e=>setEmail(e.target.value)} placeholder="email" style={{width:"100%",padding:"12px 16px",background:"rgba(255,255,255,0.05)",border:"1px solid rgba(255,255,255,0.1)",borderRadius:12,color:"#fff",fontSize:14,outline:"none",marginBottom:8,boxSizing:"border-box"}}/>
    <input value={pass} onChange={e=>setPass(e.target.value)} placeholder="password" type="password" style={{width:"100%",padding:"12px 16px",background:"rgba(255,255,255,0.05)",border:"1px solid rgba(255,255,255,0.1)",borderRadius:12,color:"#fff",fontSize:14,outline:"none",marginBottom:12,boxSizing:"border-box"}}/>
    {err&&<p style={{color:"#f87171",fontSize:12,marginBottom:8}}>{err}</p>}
    <button onClick={go} style={{width:"100%",padding:"12px",background:"linear-gradient(135deg,#F58220,#EA580C)",border:"none",borderRadius:12,color:"#fff",fontWeight:600,fontSize:15,cursor:"pointer"}}>{mode==="signup"?"Sign Up":"Log In"}</button>
    <button onClick={()=>setMode(mode==="signup"?"login":"signup")} style={{width:"100%",marginTop:8,background:"none",border:"none",color:"#888",fontSize:13,cursor:"pointer"}}>{mode==="signup"?"already have an account? log in":"need an account? sign up"}</button>
  </div>;
}
ENDPAGE

echo ""
echo "✅ Done! One file, everything you need."
echo ""
echo "  cd peel && cp .env.local.example .env.local"
echo "  # add keys to .env.local"
echo "  # paste supabase/schema.sql in Supabase SQL Editor → Run"
echo "  npm install && npm run dev"
echo ""
echo "  Repo size: ~50KB (before node_modules)"
echo "  .gitignore excludes node_modules and .next"
echo ""
echo "🍊 Ship it!"
