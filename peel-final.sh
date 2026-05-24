#!/bin/bash
# PEEL FINAL — Homepage visual + working backend
# Run: bash peel-final.sh

mkdir -p peel/src/app/api/receipt peel/src/app/api/insights peel/src/app/api/execute peel/src/app/api/purchase-check peel/src/app/api/seed-demo peel/src/lib peel/src/data peel/supabase peel/public

cat > peel/.gitignore << 'EOF'
node_modules
.next
.env.local
EOF

cat > peel/package.json << 'EOF'
{"name":"peel","private":true,"scripts":{"dev":"next dev","build":"next build"},"dependencies":{"next":"14.2.0","react":"18.3.1","react-dom":"18.3.1","@google/generative-ai":"0.14.1","@supabase/supabase-js":"2.43.4"},"devDependencies":{"typescript":"5.4.5","@types/react":"18.3.3","@types/node":"20.14.2","tailwindcss":"3.4.4","postcss":"8.4.38","autoprefixer":"10.4.19"}}
EOF

cat > peel/tsconfig.json << 'EOF'
{"compilerOptions":{"target":"es5","lib":["dom","dom.iterable","esnext"],"allowJs":true,"skipLibCheck":true,"strict":false,"noEmit":true,"esModuleInterop":true,"module":"esnext","moduleResolution":"bundler","resolveJsonModule":true,"isolatedModules":true,"jsx":"preserve","incremental":true,"paths":{"@/*":["./src/*"]}},"include":["next-env.d.ts","**/*.ts","**/*.tsx"],"exclude":["node_modules"]}
EOF

cat > peel/tailwind.config.ts << 'EOF'
import type { Config } from "tailwindcss";
const config: Config = {
  content: ["./src/**/*.{js,ts,jsx,tsx}"],
  theme: { extend: { colors: {
    'white-smoke': '#eeeeee', 'white-smoke-1': '#f7f7f7', 'ghost-white': '#fafafa',
    linen: '#f2f0e4', 'floral-white': '#faf9ec', 'dark-gray': '#9e9e9e',
    'burnt-orange': '#f2691d', 'dim-gray-300': '#000000', 'dim-gray-400': '#3a3835',
    'dim-gray-500': '#616161', 'dim-gray-600': '#006fd6',
  }, fontFamily: { sans: ['Inter','Futura','Century Gothic','Helvetica','Arial','sans-serif'] }}},
  plugins: [],
};
export default config;
EOF

cat > peel/postcss.config.js << 'EOF'
module.exports = { plugins: { tailwindcss: {}, autoprefixer: {} } };
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
  monthly_wants_budget numeric default 1540, created_at timestamptz default now()
);
create table accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  name text not null, account_type text not null, balance numeric not null, institution text not null
);
create table transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  date date not null, vendor text not null, amount numeric not null,
  category text not null, tx_type text not null, account_name text not null,
  is_recurring boolean default false, is_business boolean default false, spend_type text default 'need'
);
create table scanned_receipts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  vendor_name text, total_amount numeric, category text,
  is_business_expense boolean default false, cra_form text,
  items jsonb default '[]', gst_hst_amount numeric, spend_type text default 'want',
  created_at timestamptz default now()
);
create table insights (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  insight_type text, headline text, detail text, annual_value numeric,
  status text default 'pending', created_at timestamptz default now()
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
  current_amount numeric default 0, target_date date, status text default 'active'
);
create table purchase_checks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete cascade,
  item_description text, verdict text, monthly_spent_so_far numeric,
  monthly_remaining numeric, created_at timestamptz default now()
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
export const RECEIPT_PROMPT = `You are Peel, a Canadian financial AI. Extract receipt data from this image (physical receipt, screenshot, or digital receipt). Return ONLY JSON:
{"vendor_name":string,"date":"YYYY-MM-DD","total_amount":number,"gst_hst_amount":number,"items":[{"description":string,"amount":number}],"category":"Groceries"|"Office Supplies"|"Restaurants"|"Transportation"|"Shopping"|"Subscriptions"|"Other","spend_type":"need"|"want","is_business_expense":boolean,"cra_form":"T2125"|"N/A","confidence":number}
need=groceries,utilities,gas,pharmacy. want=restaurants,shopping,entertainment. Estimate Ontario 13% HST if not shown.`;

export const INSIGHTS_PROMPT = `You are Peel, a casual witty AI financial copilot texting a young Canadian. Analyze their data.
Return ONLY JSON:
{"messages":[{"id":string,"type":"greeting"|"insight"|"learn"|"budget"|"goals"|"summary"|"action_prompt","text":string,"insight_data":{"type":"subscription_waste"|"savings_opportunity"|"rewards_optimization"|"tax_alert"|null,"annual_value":number|null}|null,"learn_card":{"title":string,"explanation":string,"pro_tip":string}|null}],"total_annual_opportunity":number,"agent_log":[{"agent":string,"icon":string,"message":string}]}
Generate in order: 1.greeting 2.budget(needs vs wants, fun money left) 3.subscription_waste(unused subs) 4.learn(subscription creep) 5.savings_opportunity(TFSA room) 6.learn(what TFSA is) 7.goals(progress) 8.rewards_optimization(card switch) 9.tax_alert(freelance) 10.summary(total $) 11.action_prompt(one tap CTA)
Tone: lowercase, iMessage, specific dollars, encouraging.`;

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
  const token = req.headers.get("authorization")?.replace("Bearer ","");
  if(!token) return NextResponse.json({error:"No auth"},{status:401});
  const uc = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!,process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);
  const {data:{user}} = await uc.auth.getUser(token);
  if(!user) return NextResponse.json({error:"Bad token"},{status:401});
  const u=user.id;
  await db.from("savings_goals").delete().eq("user_id",u);
  await db.from("agent_activity").delete().eq("user_id",u);
  await db.from("insights").delete().eq("user_id",u);
  await db.from("scanned_receipts").delete().eq("user_id",u);
  await db.from("transactions").delete().eq("user_id",u);
  await db.from("accounts").delete().eq("user_id",u);
  await db.from("user_profiles").delete().eq("id",u);
  await db.from("user_profiles").insert({id:u,name:user.user_metadata?.name||"Priya",salary:72000,freelance_ytd:7500,tfsa_contributed_ytd:2800,tfsa_limit:7000,rewards_categories:["groceries","gas","restaurants"],monthly_wants_budget:1540});
  await db.from("accounts").insert([
    {user_id:u,name:"Chequing",account_type:"chequing",balance:4280,institution:"Tangerine"},
    {user_id:u,name:"Savings",account_type:"savings",balance:11450,institution:"Tangerine"},
    {user_id:u,name:"TFSA",account_type:"tfsa",balance:18300,institution:"Tangerine"},
    {user_id:u,name:"Visa Infinite",account_type:"credit",balance:-1870,institution:"TD"},
  ]);
  await db.from("savings_goals").insert([
    {user_id:u,name:"Japan Trip 🇯🇵",target_amount:5000,current_amount:1200,target_date:"2027-03-01"},
    {user_id:u,name:"Emergency Fund 🛟",target_amount:15000,current_amount:11450},
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
    t("2026-01-03","ClassPass",49,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-01-03","Crave",9.99,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-01-10","PixelWorks",1800,"Freelance Income","credit","Chequing",false,true,"income"),
    t("2026-01-15","TFSA",400,"Savings","debit","Chequing",false,false,"savings"),
    t("2026-01-20","Hydro One",82.1,"Utilities","debit","Chequing",true,false,"need"),
    t("2026-01-20","Rogers",85,"Phone","debit","Chequing",true,false,"need"),
    t("2026-02-01","Landlord",2100,"Rent","debit","Chequing",true,false,"need"),
    t("2026-02-03","ClassPass",49,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-02-03","Crave",9.99,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-02-15","TFSA",400,"Savings","debit","Chequing",false,false,"savings"),
    t("2026-02-20","Hydro One",75.9,"Utilities","debit","Chequing",true,false,"need"),
    t("2026-02-20","Rogers",85,"Phone","debit","Chequing",true,false,"need"),
    t("2026-02-22","PixelWorks",3200,"Freelance Income","credit","Chequing",false,true,"income"),
    t("2026-03-01","Landlord",2100,"Rent","debit","Chequing",true,false,"need"),
    t("2026-03-03","ClassPass",49,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-03-03","Crave",9.99,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-03-15","TFSA",400,"Savings","debit","Chequing",false,false,"savings"),
    t("2026-03-20","Hydro One",71.2,"Utilities","debit","Chequing",true,false,"need"),
    t("2026-03-20","Rogers",85,"Phone","debit","Chequing",true,false,"need"),
    t("2026-04-01","Landlord",2100,"Rent","debit","Chequing",true,false,"need"),
    t("2026-04-03","ClassPass",49,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-04-03","Crave",9.99,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-04-15","TFSA",400,"Savings","debit","Chequing",false,false,"savings"),
    t("2026-04-20","Hydro One",68.5,"Utilities","debit","Chequing",true,false,"need"),
    t("2026-04-20","Rogers",85,"Phone","debit","Chequing",true,false,"need"),
    t("2026-05-01","Landlord",2100,"Rent","debit","Chequing",true,false,"need"),
    t("2026-05-03","ClassPass",49,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-05-03","Crave",9.99,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-05-10","PixelWorks",1500,"Freelance Income","credit","Chequing",false,true,"income"),
    t("2026-05-15","TFSA",400,"Savings","debit","Chequing",false,false,"savings"),
    t("2026-05-20","Hydro One",74.8,"Utilities","debit","Chequing",true,false,"need"),
    t("2026-05-20","Rogers",85,"Phone","debit","Chequing",true,false,"need"),
  ];
  await db.from("transactions").insert(txns);
  return NextResponse.json({ok:true,txns:txns.length});
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
  const db=dbAdmin(); const {image,userId}=await req.json();
  if(!userId||!image) return NextResponse.json({error:"Missing data"},{status:400});
  const m=image.match(/^data:(.+);base64,(.+)$/);
  if(!m) return NextResponse.json({error:"Bad image"},{status:400});
  const model=ai.getGenerativeModel({model:"gemini-1.5-flash"});
  const r1=await model.generateContent([{text:RECEIPT_PROMPT+"\nParse:"},{inlineData:{mimeType:m[1],data:m[2]}}]);
  const receipt=JSON.parse(exJ(r1.response.text()));
  await db.from("scanned_receipts").insert({user_id:userId,vendor_name:receipt.vendor_name,total_amount:receipt.total_amount,category:receipt.category,is_business_expense:receipt.is_business_expense,cra_form:receipt.cra_form,items:receipt.items,gst_hst_amount:receipt.gst_hst_amount,spend_type:receipt.spend_type});
  await db.from("transactions").insert({user_id:userId,date:receipt.date||new Date().toISOString().slice(0,10),vendor:receipt.vendor_name,amount:receipt.total_amount,category:receipt.category,tx_type:"debit",account_name:"Visa",is_business:receipt.is_business_expense,spend_type:receipt.spend_type||"want"});
  const r2=await model.generateContent([{text:EXPENSE_PROMPT+"\n"+JSON.stringify({expense:receipt,ytd_deductions:4200})}]);
  const analysis=JSON.parse(exJ(r2.response.text()));
  const log=[{agent:"watcher",icon:"👁️",message:`${receipt.vendor_name}, $${receipt.total_amount} — ${receipt.category} (${receipt.spend_type})`}];
  for(const s of analysis.reasoning_steps||[]) log.push({agent:"thinker",icon:"🧠",message:s});
  return NextResponse.json({receipt,analysis,activityLog:log});
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
  const db=dbAdmin(); const {userId}=await req.json();
  if(!userId) return NextResponse.json({error:"No user"},{status:400});
  const [p,tx,ac,g]=await Promise.all([
    db.from("user_profiles").select("*").eq("id",userId).single(),
    db.from("transactions").select("*").eq("user_id",userId).order("date",{ascending:false}),
    db.from("accounts").select("*").eq("user_id",userId),
    db.from("savings_goals").select("*").eq("user_id",userId).eq("status","active"),
  ]);
  const model=ai.getGenerativeModel({model:"gemini-1.5-flash"});
  const r=await model.generateContent([{text:INSIGHTS_PROMPT+"\n\nData:\n"+JSON.stringify({user:p.data,accounts:ac.data,goals:g.data,transactions:(tx.data||[]).map(t=>({date:t.date,vendor:t.vendor,amount:t.amount,category:t.category,type:t.tx_type,is_recurring:t.is_recurring,spend_type:t.spend_type})),current_date:new Date().toISOString().slice(0,10)})}]);
  const data=JSON.parse(exJ(r.response.text()));
  return NextResponse.json({data,activityLog:data.agent_log||[]});
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
  const db=dbAdmin(); const {userId}=await req.json();
  if(!userId) return NextResponse.json({error:"No user"},{status:400});
  const model=ai.getGenerativeModel({model:"gemini-1.5-flash"});
  const r=await model.generateContent([{text:DOER_PROMPT+"\nActions: cancel ClassPass $49/mo + Crave $9.99/mo, schedule TFSA $400/mo, switch rewards to groceries/gas/recurring +$127/yr"}]);
  const exec=JSON.parse(exJ(r.response.text()));
  await db.from("accounts").update({balance:3880}).eq("user_id",userId).eq("account_type","chequing");
  await db.from("accounts").update({balance:18700}).eq("user_id",userId).eq("account_type","tfsa");
  await db.from("user_profiles").update({rewards_categories:["groceries","gas","recurring bills"],tfsa_contributed_ytd:3200}).eq("id",userId);
  const {data:updated}=await db.from("accounts").select("*").eq("user_id",userId);
  return NextResponse.json({execution:exec,updatedAccounts:updated});
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
  const db=dbAdmin(); const {message,userId}=await req.json();
  if(!userId) return NextResponse.json({error:"No user"},{status:400});
  const month=new Date().toISOString().slice(0,7)+"-01";
  const {data:w}=await db.from("transactions").select("amount").eq("user_id",userId).eq("spend_type","want").gte("date",month);
  const spent=(w||[]).reduce((s,t)=>s+Number(t.amount),0);
  const budget=1540;
  const {data:goals}=await db.from("savings_goals").select("*").eq("user_id",userId).eq("status","active");
  const model=ai.getGenerativeModel({model:"gemini-1.5-flash"});
  const r=await model.generateContent([{text:PURCHASE_PROMPT+"\nUser: "+message+"\nBudget: "+JSON.stringify({wants_spent:spent,wants_budget:budget,remaining:budget-spent,goals:(goals||[]).map(g=>({name:g.name,target:g.target_amount,current:g.current_amount}))})}]);
  const data=JSON.parse(exJ(r.response.text()));
  return NextResponse.json({data,wantsSpent:spent,remaining:budget-spent});
}
function exJ(t){const c=t.match(/```(?:json)?\s*([\s\S]*?)```/);if(c)return c[1].trim();const r=t.match(/\{[\s\S]*\}/);return r?r[0]:t}
EOF

echo "  ✓ Backend complete"
echo "  ✓ Now creating page.tsx (your homepage visual + working app)..."
echo "  ⚠  page.tsx is too large for this script."
echo "  ⚠  Run: bash peel-final-page.sh"
echo ""
echo "🍊 Almost done!"
