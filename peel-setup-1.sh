#!/bin/bash
# ============================================================
# PEEL SETUP — Part 1 of 2
# Config, schema, lib, prompts, API routes, seed script
# Run: bash peel-setup-1.sh
# Then: bash peel-setup-2.sh
# ============================================================

echo "🍊 Creating Peel project (Part 1)..."

mkdir -p peel/src/app/api/receipt
mkdir -p peel/src/app/api/insights
mkdir -p peel/src/app/api/execute
mkdir -p peel/src/app/api/purchase-check
mkdir -p peel/src/data
mkdir -p peel/src/lib
mkdir -p peel/src/scripts
mkdir -p peel/supabase

# ─── package.json ─────────────────────────────────────────────
cat > peel/package.json << 'EOF'
{
  "name": "peel",
  "version": "0.1.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "seed": "npx tsx src/scripts/seed.ts"
  },
  "dependencies": {
    "next": "^14.2.0",
    "react": "^18.3.0",
    "react-dom": "^18.3.0",
    "@google/generative-ai": "^0.14.0",
    "@supabase/supabase-js": "^2.43.0",
    "framer-motion": "^11.2.0",
    "lucide-react": "^0.390.0"
  },
  "devDependencies": {
    "typescript": "^5.4.0",
    "@types/react": "^18.3.0",
    "@types/node": "^20.14.0",
    "tailwindcss": "^3.4.0",
    "postcss": "^8.4.0",
    "autoprefixer": "^10.4.0",
    "tsx": "^4.15.0"
  }
}
EOF

# ─── tsconfig.json ────────────────────────────────────────────
cat > peel/tsconfig.json << 'EOF'
{
  "compilerOptions": {
    "target": "es5",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [{ "name": "next" }],
    "paths": { "@/*": ["./src/*"] }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
EOF

# ─── tailwind.config.ts ──────────────────────────────────────
cat > peel/tailwind.config.ts << 'EOF'
import type { Config } from "tailwindcss";
const config: Config = {
  content: ["./src/**/*.{js,ts,jsx,tsx,mdx}"],
  theme: {
    extend: {
      colors: {
        tangerine: {
          50: "#FFF7ED", 100: "#FFEDD5", 200: "#FED7AA", 300: "#FDBA74",
          400: "#FB923C", 500: "#F58220", 600: "#EA580C", 700: "#C2410C",
          800: "#9A3412", 900: "#7C2D12",
        },
        navy: { 900: "#0F172A", 800: "#1E293B", 700: "#334155" },
      },
    },
  },
  plugins: [],
};
export default config;
EOF

# ─── postcss.config.js ───────────────────────────────────────
cat > peel/postcss.config.js << 'EOF'
module.exports = { plugins: { tailwindcss: {}, autoprefixer: {} } };
EOF

# ─── next.config.js ──────────────────────────────────────────
cat > peel/next.config.js << 'EOF'
/** @type {import('next').NextConfig} */
const nextConfig = {};
module.exports = nextConfig;
EOF

# ─── .env.local.example ──────────────────────────────────────
cat > peel/.env.local.example << 'EOF'
GEMINI_API_KEY=your-gemini-key
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key
EOF

# ─── supabase/schema.sql (v2 — full) ─────────────────────────
cat > peel/supabase/schema.sql << 'EOF'
create table if not exists user_profiles (
  id uuid primary key default gen_random_uuid(),
  name text not null, age integer not null, occupation text,
  salary numeric not null, freelance_ytd numeric default 0,
  tfsa_contributed_ytd numeric default 0, tfsa_limit numeric default 7000,
  rrsp_room numeric default 0,
  rewards_categories text[] default '{"groceries","gas","restaurants"}',
  goals text[] default '{}',
  monthly_needs_budget numeric default 2600,
  monthly_wants_budget numeric default 540,
  created_at timestamptz default now()
);

create table if not exists accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references user_profiles(id) on delete cascade,
  name text not null, account_type text not null,
  balance numeric not null, institution text not null,
  created_at timestamptz default now()
);

create table if not exists transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references user_profiles(id) on delete cascade,
  date date not null, vendor text not null, amount numeric not null,
  category text not null, tx_type text not null, account_name text not null,
  is_recurring boolean default false, is_business boolean default false,
  spend_type text default 'need',
  created_at timestamptz default now()
);

create table if not exists scanned_receipts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references user_profiles(id) on delete cascade,
  vendor_name text, receipt_date date, total_amount numeric,
  subtotal numeric, gst_hst_amount numeric, gst_hst_rate text,
  items jsonb default '[]', category text,
  is_business_expense boolean default false,
  cra_form text, cra_line_item text, confidence numeric,
  source text default 'camera',
  created_at timestamptz default now()
);

create table if not exists insights (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references user_profiles(id) on delete cascade,
  insight_type text not null, emoji text, headline text not null,
  detail text, annual_value numeric, action_label text,
  action_id text, reasoning_steps text[] default '{}',
  status text default 'pending',
  created_at timestamptz default now()
);

create table if not exists agent_activity (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references user_profiles(id) on delete cascade,
  agent text not null, icon text not null, message text not null,
  session_id text, created_at timestamptz default now()
);

create table if not exists executed_actions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references user_profiles(id) on delete cascade,
  action_id text not null, action_label text,
  execution_steps jsonb default '[]', completion_summary text,
  status text default 'completed',
  created_at timestamptz default now()
);

create table if not exists savings_goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references user_profiles(id) on delete cascade,
  name text not null, target_amount numeric not null,
  current_amount numeric default 0, target_date date,
  monthly_contribution numeric default 0,
  priority integer default 1, status text default 'active',
  created_at timestamptz default now()
);

create table if not exists purchase_checks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references user_profiles(id) on delete cascade,
  item_description text not null, estimated_price numeric,
  ai_response text, verdict text,
  monthly_spent_so_far numeric, monthly_remaining numeric,
  created_at timestamptz default now()
);

create index if not exists idx_tx_user_date on transactions(user_id, date desc);
create index if not exists idx_tx_spend on transactions(user_id, spend_type);
create index if not exists idx_activity_session on agent_activity(session_id, created_at);
create index if not exists idx_insights_user on insights(user_id, created_at desc);
create index if not exists idx_goals_user on savings_goals(user_id, status);

alter publication supabase_realtime add table agent_activity;
alter publication supabase_realtime add table insights;
alter publication supabase_realtime add table scanned_receipts;
alter publication supabase_realtime add table accounts;
alter publication supabase_realtime add table savings_goals;
alter publication supabase_realtime add table purchase_checks;
EOF

# ─── src/lib/supabase.ts ─────────────────────────────────────
cat > peel/src/lib/supabase.ts << 'EOF'
import { createClient } from "@supabase/supabase-js";

export const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);

export function getServiceSupabase() {
  return createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!
  );
}
EOF

# ─── src/data/prompts.ts ─────────────────────────────────────
cat > peel/src/data/prompts.ts << 'ENDPROMPTS'
export const WATCHER_RECEIPT_PROMPT = `You are the Watcher agent in Peel, a Canadian AI financial copilot.
Extract structured data from this receipt image (could be a photo of a physical receipt, a screenshot of an online order, or a digital receipt).

Return ONLY a JSON object:
{
  "vendor_name": string,
  "date": "YYYY-MM-DD",
  "total_amount": number,
  "subtotal": number,
  "gst_hst_amount": number,
  "gst_hst_rate": string,
  "items": [{ "description": string, "amount": number }],
  "payment_method": "cash" | "debit" | "credit" | "other",
  "category": one of ["Office Supplies", "Software & Subscriptions", "Meals & Entertainment", "Transportation", "Professional Development", "Equipment", "Groceries", "Personal", "Shopping", "Other"],
  "spend_type": "need" | "want",
  "is_business_expense": boolean,
  "cra_form": "T2125" | "N/A",
  "cra_line_item": string or null,
  "confidence": number 0-1
}

Spend type rules:
- "need": groceries, utilities, gas, pharmacy, transit, insurance
- "want": restaurants, shopping, entertainment, clothing, electronics (personal), subscriptions (entertainment)
- If business expense, mark as "want" (it's discretionary even if deductible)

If HST/GST not shown, estimate Ontario 13% HST. Return ONLY valid JSON.`;

export const THINKER_INSIGHTS_PROMPT = `You are Peel, a warm, sharp, slightly witty AI financial copilot for young Canadians. You talk like a smart friend who's great with money.

You're texting Priya (27, PM in Toronto, freelances on the side, saving for Japan trip).

Her budget framework (50/30/20 of ~$5,125/mo take-home):
- Needs: ~$2,560 (50%)
- Wants: ~$1,540 (30%)
- Savings: ~$1,025 (20%)

Her savings goals:
- Japan Trip: $1,200 / $5,000 (target: March 2027)
- Emergency Fund: $11,450 / $15,000

Return ONLY JSON:
{
  "messages": [
    {
      "id": string,
      "type": "greeting" | "insight" | "learn" | "budget_check" | "goals" | "summary" | "action_prompt",
      "text": string (1-3 sentences, conversational),
      "emoji": string or null,
      "insight_data": {
        "type": "subscription_waste" | "savings_opportunity" | "rewards_optimization" | "tax_alert" | "needs_wants" | null,
        "annual_value": number or null,
        "action_id": string or null,
        "action_label": string or null
      } or null,
      "learn_card": {
        "title": string,
        "explanation": string (2-3 sentences plain language),
        "pro_tip": string
      } or null
    }
  ],
  "total_annual_opportunity": number,
  "agent_log": [
    { "agent": "watcher" | "thinker" | "doer", "icon": string, "message": string }
  ]
}

Generate IN ORDER:
1. type "greeting": casual hello, mention you analyzed 6 months
2. type "budget_check" (needs_wants): break down this month's spending into needs vs wants vs savings. show specific dollars and percentages. compare to the 50/30/20 targets. mention how much "fun money" is left this month. be specific.
3. type "insight" (subscription_waste): ClassPass $49/mo + Crave $9.99/mo unused since Feb = $707.88/yr
4. type "learn": subscription creep explanation
5. type "insight" (savings_opportunity): TFSA $2,800 of $7,000 contributed. $4,200 room. $400/mo safe.
6. type "learn": what a TFSA is and why it matters at 27
7. type "goals": show savings goal progress with emoji. japan trip at 24%, emergency fund at 76%. mention if on track.
8. type "insight" (rewards_optimization): card set wrong, switch = $127/yr
9. type "insight" (tax_alert): freelance $7,500 YTD, set aside 25%, approaching GST threshold
10. type "learn": T2125 self-employment primer
11. type "summary": "$1,027/year on the table. want me to fix all three?"
12. type "action_prompt": "one tap. cancel subs, set up tfsa, switch rewards. you just say go. 🍊"

TONE: lowercase, casual, iMessage vibes. specific dollar amounts always. "here's the move" not "I recommend." emojis natural (1-2 per msg max). encouraging, never preachy.`;

export const THINKER_EXPENSE_PROMPT = `You are Peel, analyzing a newly scanned receipt (could be physical or digital). Conversational, texting the user.

Return ONLY JSON:
{
  "messages": [
    { "type": "receipt_parsed", "text": string, "emoji": string },
    { "type": "tax_note", "text": string, "emoji": string },
    { "type": "budget_note", "text": string, "emoji": string }
  ],
  "reasoning_steps": [string],
  "tax_implications": {
    "is_deductible": boolean, "cra_category": string,
    "ytd_deductions_updated": number, "gst_claimable": number
  }
}

The budget_note should say whether this was a need or want, and how much fun money they have left this month.
Be casual, lowercase, specific with dollars.`;

export const DOER_NARRATIVE_PROMPT = `You are Peel's Doer agent. Generate execution steps as chat messages.

Return ONLY JSON:
{
  "execution_messages": [
    { "text": string, "delay_ms": number (600-1000), "emoji": string }
  ],
  "completion_message": string,
  "execution_steps": [
    { "step_number": number, "display_message": string (under 50 chars), "icon": "⚡", "delay_ms": number }
  ]
}

4-6 messages. Casual, lowercase, specific dollars. Celebrations after each action. Mic drop at the end.`;

export const PURCHASE_CHECK_PROMPT = `You are Peel, a young person's financial bestie. They want to buy something and want your honest take.

Their context:
- Monthly take-home: ~$5,125
- Monthly wants budget: ~$1,540 (30%)
- Wants spent so far this month: provided in data
- Savings goals: Japan trip ($1,200/$5,000), Emergency fund ($11,450/$15,000)

Return ONLY JSON:
{
  "verdict": "go_for_it" | "maybe_wait" | "skip_it",
  "messages": [
    { "text": string, "emoji": string }
  ],
  "context": {
    "wants_spent": number,
    "wants_remaining": number,
    "over_budget_by": number or null,
    "goals_on_track": boolean
  }
}

TONE RULES:
- NEVER shame. NEVER say "you can't afford this."
- go_for_it: be excited! "treat yourself 🎉"
- maybe_wait: kind + honest. "cute but you've hit your fun budget. wait till next month?"
- skip_it: supportive. "screenshot it, revisit next month? your japan fund needs love 🇯🇵"
- Always reference specific spending numbers and goals by name
- 2-3 messages, casual, lowercase`;
ENDPROMPTS

echo "  ✓ Prompts created"

# ─── src/app/layout.tsx ──────────────────────────────────────
cat > peel/src/app/layout.tsx << 'EOF'
import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "Peel — AI Financial Copilot",
  description: "Forward banking, for real this time.",
};

export const viewport: Viewport = {
  width: "device-width", initialScale: 1, maximumScale: 1,
  userScalable: false, themeColor: "#0A0A0F",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return <html lang="en"><body>{children}</body></html>;
}
EOF

# ─── src/app/globals.css ─────────────────────────────────────
cat > peel/src/app/globals.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

:root { --tangerine: #F58220; }
html { font-size: 16px; }
body {
  background: #0A0A0F; color: white;
  font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Segoe UI', Roboto, sans-serif;
  -webkit-font-smoothing: antialiased; overscroll-behavior: none;
}
.app-shell { height: 100dvh; overflow: hidden; }
.scroll-area { overflow-y: auto; -webkit-overflow-scrolling: touch; scrollbar-width: none; }
.scroll-area::-webkit-scrollbar { display: none; }
.glass { background: rgba(255,255,255,0.04); backdrop-filter: blur(20px); -webkit-backdrop-filter: blur(20px); border: 1px solid rgba(255,255,255,0.06); }
.glass-bright { background: rgba(255,255,255,0.07); backdrop-filter: blur(24px); -webkit-backdrop-filter: blur(24px); border: 1px solid rgba(255,255,255,0.1); }
.gradient-text { background: linear-gradient(135deg, #F58220, #FF6B35, #FFB347); -webkit-background-clip: text; -webkit-text-fill-color: transparent; background-clip: text; }
.glow-sm { box-shadow: 0 0 20px rgba(245,130,32,0.15); }
.glow-lg { box-shadow: 0 0 60px rgba(245,130,32,0.25), 0 0 120px rgba(245,130,32,0.1); }
@keyframes notifPulse { 0% { box-shadow: 0 0 0 0 rgba(245,130,32,0.6); } 70% { box-shadow: 0 0 0 15px rgba(245,130,32,0); } 100% { box-shadow: 0 0 0 0 rgba(245,130,32,0); } }
.notif-pulse { animation: notifPulse 2s infinite; }
@keyframes bounce { 0%,80%,100% { transform: translateY(0); } 40% { transform: translateY(-6px); } }
.typing-dot { animation: bounce 1.4s infinite; }
.typing-dot:nth-child(2) { animation-delay: 0.2s; }
.typing-dot:nth-child(3) { animation-delay: 0.4s; }
.bubble-ai { border-radius: 20px 20px 20px 4px; }
.bubble-user { border-radius: 20px 20px 4px 20px; }
.tabular-nums { font-variant-numeric: tabular-nums; }
EOF

# ─── API: receipt ─────────────────────────────────────────────
cat > peel/src/app/api/receipt/route.ts << 'EOF'
import { NextRequest, NextResponse } from "next/server";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { WATCHER_RECEIPT_PROMPT, THINKER_EXPENSE_PROMPT } from "@/data/prompts";
import { getServiceSupabase } from "@/lib/supabase";

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || "");
const PRIYA_ID = "00000000-0000-0000-0000-000000000001";

export async function POST(req: NextRequest) {
  const db = getServiceSupabase();
  const sessionId = crypto.randomUUID();
  try {
    const { image } = await req.json();
    const matches = image.match(/^data:(.+);base64,(.+)$/);
    if (!matches) return NextResponse.json({ error: "Invalid image" }, { status: 400 });

    await db.from("agent_activity").insert({ user_id: PRIYA_ID, agent: "watcher", icon: "👁️", message: "Scanning receipt...", session_id: sessionId });

    const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });
    const watcherResult = await model.generateContent([
      { text: WATCHER_RECEIPT_PROMPT + "\n\nParse this receipt:" },
      { inlineData: { mimeType: matches[1], data: matches[2] } },
    ]);
    const receipt = JSON.parse(extractJSON(watcherResult.response.text()));

    await db.from("scanned_receipts").insert({
      user_id: PRIYA_ID, vendor_name: receipt.vendor_name, receipt_date: receipt.date,
      total_amount: receipt.total_amount, subtotal: receipt.subtotal,
      gst_hst_amount: receipt.gst_hst_amount, gst_hst_rate: receipt.gst_hst_rate,
      items: receipt.items, category: receipt.category,
      is_business_expense: receipt.is_business_expense, cra_form: receipt.cra_form,
      cra_line_item: receipt.cra_line_item, confidence: receipt.confidence, source: "upload",
    });

    await db.from("transactions").insert({
      user_id: PRIYA_ID, date: receipt.date || new Date().toISOString().split("T")[0],
      vendor: receipt.vendor_name, amount: receipt.total_amount, category: receipt.category,
      tx_type: "debit", account_name: "Visa", is_recurring: false,
      is_business: receipt.is_business_expense, spend_type: receipt.spend_type || "want",
    });

    await db.from("agent_activity").insert({ user_id: PRIYA_ID, agent: "watcher", icon: "👁️", message: `${receipt.vendor_name}, $${receipt.total_amount} — ${receipt.category}`, session_id: sessionId });

    const thinkerResult = await model.generateContent([{
      text: THINKER_EXPENSE_PROMPT + "\n\nNew expense:\n" + JSON.stringify({ new_expense: receipt, ytd_business_deductions: 4200, ytd_freelance_revenue: 7500 }),
    }]);
    const analysis = JSON.parse(extractJSON(thinkerResult.response.text()));

    for (const step of analysis.reasoning_steps || []) {
      await db.from("agent_activity").insert({ user_id: PRIYA_ID, agent: "thinker", icon: "🧠", message: step, session_id: sessionId });
    }
    await db.from("agent_activity").insert({ user_id: PRIYA_ID, agent: "doer", icon: "⚡", message: "Added to expense report.", session_id: sessionId });

    const { data: activityLog } = await db.from("agent_activity").select("agent, icon, message").eq("session_id", sessionId).order("created_at");
    return NextResponse.json({ receipt, analysis, activityLog, sessionId });
  } catch (error: any) {
    console.error("Receipt error:", error);
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
}

function extractJSON(text: string): string {
  const cb = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (cb) return cb[1].trim();
  const raw = text.match(/\{[\s\S]*\}/);
  if (raw) return raw[0];
  return text;
}
EOF

# ─── API: insights ────────────────────────────────────────────
cat > peel/src/app/api/insights/route.ts << 'EOF'
import { NextRequest, NextResponse } from "next/server";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { THINKER_INSIGHTS_PROMPT } from "@/data/prompts";
import { getServiceSupabase } from "@/lib/supabase";

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || "");
const PRIYA_ID = "00000000-0000-0000-0000-000000000001";

export async function POST(req: NextRequest) {
  const db = getServiceSupabase();
  const sessionId = crypto.randomUUID();
  try {
    const [profileRes, txRes, accountsRes, goalsRes] = await Promise.all([
      db.from("user_profiles").select("*").eq("id", PRIYA_ID).single(),
      db.from("transactions").select("*").eq("user_id", PRIYA_ID).order("date", { ascending: false }),
      db.from("accounts").select("*").eq("user_id", PRIYA_ID),
      db.from("savings_goals").select("*").eq("user_id", PRIYA_ID).eq("status", "active"),
    ]);

    const profile = profileRes.data;
    const transactions = txRes.data || [];
    const accounts = accountsRes.data || [];
    const goals = goalsRes.data || [];

    await db.from("agent_activity").insert([
      { user_id: PRIYA_ID, agent: "orchestrator", icon: "🔄", message: "Starting analysis...", session_id: sessionId },
      { user_id: PRIYA_ID, agent: "watcher", icon: "👁️", message: `Scanning ${transactions.length} transactions`, session_id: sessionId },
    ]);

    const txSummary = {
      user: {
        name: profile?.name, age: profile?.age, salary: profile?.salary,
        freelance_ytd: profile?.freelance_ytd, tfsa_contributed_ytd: profile?.tfsa_contributed_ytd,
        tfsa_limit: profile?.tfsa_limit, tangerine_rewards_categories: profile?.rewards_categories,
        monthly_needs_budget: profile?.monthly_needs_budget, monthly_wants_budget: profile?.monthly_wants_budget,
        accounts: accounts.map((a: any) => ({ name: a.name, type: a.account_type, balance: a.balance, institution: a.institution })),
      },
      savings_goals: goals.map((g: any) => ({ name: g.name, target: g.target_amount, current: g.current_amount, target_date: g.target_date })),
      transactions: transactions.map((t: any) => ({
        date: t.date, vendor: t.vendor, amount: t.amount, category: t.category,
        type: t.tx_type, is_recurring: t.is_recurring, is_business: t.is_business, spend_type: t.spend_type,
      })),
      current_date: "2026-05-24",
    };

    const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });
    const result = await model.generateContent([{ text: THINKER_INSIGHTS_PROMPT + "\n\nData:\n" + JSON.stringify(txSummary) }]);
    const data = JSON.parse(extractJSON(result.response.text()));

    for (const entry of data.agent_log || []) {
      await db.from("agent_activity").insert({ user_id: PRIYA_ID, agent: entry.agent, icon: entry.icon, message: entry.message, session_id: sessionId });
    }
    for (const msg of data.messages || []) {
      if (msg.insight_data?.type) {
        await db.from("insights").insert({
          user_id: PRIYA_ID, insight_type: msg.insight_data.type, emoji: msg.emoji,
          headline: (msg.text || "").substring(0, 100), detail: msg.text,
          annual_value: msg.insight_data.annual_value, action_label: msg.insight_data.action_label,
          action_id: msg.insight_data.action_id, status: "pending",
        });
      }
    }

    const { data: activityLog } = await db.from("agent_activity").select("agent, icon, message").eq("session_id", sessionId).order("created_at");
    return NextResponse.json({ data, activityLog, sessionId });
  } catch (error: any) {
    console.error("Insights error:", error);
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
}

function extractJSON(text: string): string {
  const cb = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (cb) return cb[1].trim();
  const raw = text.match(/\{[\s\S]*\}/);
  if (raw) return raw[0];
  return text;
}
EOF

# ─── API: execute ─────────────────────────────────────────────
cat > peel/src/app/api/execute/route.ts << 'EOF'
import { NextRequest, NextResponse } from "next/server";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { DOER_NARRATIVE_PROMPT } from "@/data/prompts";
import { getServiceSupabase } from "@/lib/supabase";

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || "");
const PRIYA_ID = "00000000-0000-0000-0000-000000000001";

export async function POST(req: NextRequest) {
  const db = getServiceSupabase();
  const sessionId = crypto.randomUUID();
  try {
    const { actions } = await req.json();
    const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });

    const defaultActions = [
      { action_id: "cancel_subs", label: "Cancel subscriptions", details: "ClassPass $49/mo + Crave $9.99/mo = $707.88/yr" },
      { action_id: "tfsa_auto", label: "TFSA auto-save", details: "$400/mo. Balance $18,300. Room $4,200." },
      { action_id: "switch_rewards", label: "Optimize rewards", details: "Switch to groceries/gas/recurring. +$127/yr" },
    ];

    const result = await model.generateContent([{ text: DOER_NARRATIVE_PROMPT + "\n\nExecute:\n" + JSON.stringify({ actions_to_execute: actions || defaultActions }) }]);
    const execution = JSON.parse(extractJSON(result.response.text()));

    for (const step of execution.execution_steps || []) {
      await db.from("agent_activity").insert({ user_id: PRIYA_ID, agent: "doer", icon: "⚡", message: step.display_message, session_id: sessionId });
    }

    await db.from("executed_actions").insert({ user_id: PRIYA_ID, action_id: "fix_all", action_label: "Fix all three", execution_steps: execution.execution_steps, completion_summary: execution.completion_message, status: "completed" });
    await db.from("insights").update({ status: "approved" }).eq("user_id", PRIYA_ID).eq("status", "pending");
    await db.from("accounts").update({ balance: 3880 }).eq("user_id", PRIYA_ID).eq("account_type", "chequing");
    await db.from("accounts").update({ balance: 18700 }).eq("user_id", PRIYA_ID).eq("account_type", "tfsa");
    await db.from("user_profiles").update({ rewards_categories: ["groceries", "gas", "recurring bills"], tfsa_contributed_ytd: 3200 }).eq("id", PRIYA_ID);

    if (execution.completion_message) {
      await db.from("agent_activity").insert({ user_id: PRIYA_ID, agent: "doer", icon: "✅", message: execution.completion_message, session_id: sessionId });
    }

    const { data: updatedAccounts } = await db.from("accounts").select("*").eq("user_id", PRIYA_ID);
    const { data: activityLog } = await db.from("agent_activity").select("agent, icon, message").eq("session_id", sessionId).order("created_at");
    return NextResponse.json({ execution, activityLog, updatedAccounts, sessionId });
  } catch (error: any) {
    console.error("Execute error:", error);
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
}

function extractJSON(text: string): string {
  const cb = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (cb) return cb[1].trim();
  const raw = text.match(/\{[\s\S]*\}/);
  if (raw) return raw[0];
  return text;
}
EOF

# ─── API: purchase-check ─────────────────────────────────────
cat > peel/src/app/api/purchase-check/route.ts << 'EOF'
import { NextRequest, NextResponse } from "next/server";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { PURCHASE_CHECK_PROMPT } from "@/data/prompts";
import { getServiceSupabase } from "@/lib/supabase";

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || "");
const PRIYA_ID = "00000000-0000-0000-0000-000000000001";

export async function POST(req: NextRequest) {
  const db = getServiceSupabase();
  try {
    const { message } = await req.json();

    // Get current month's want spending
    const startOfMonth = new Date().toISOString().slice(0, 7) + "-01";
    const { data: wantsTxns } = await db.from("transactions")
      .select("amount").eq("user_id", PRIYA_ID)
      .eq("spend_type", "want").gte("date", startOfMonth);

    const wantsSpent = (wantsTxns || []).reduce((s: number, t: any) => s + Number(t.amount), 0);
    const wantsBudget = 1540;
    const remaining = wantsBudget - wantsSpent;

    // Get savings goals
    const { data: goals } = await db.from("savings_goals").select("*")
      .eq("user_id", PRIYA_ID).eq("status", "active");

    const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });
    const result = await model.generateContent([{
      text: PURCHASE_CHECK_PROMPT + "\n\nUser says: " + message +
        "\n\nBudget context: " + JSON.stringify({
          wants_spent_this_month: wantsSpent,
          wants_budget: wantsBudget,
          wants_remaining: remaining,
          savings_goals: (goals || []).map((g: any) => ({
            name: g.name, target: g.target_amount, current: g.current_amount, target_date: g.target_date,
          })),
        }),
    }]);

    const data = JSON.parse(extractJSON(result.response.text()));

    // Save to purchase_checks table
    await db.from("purchase_checks").insert({
      user_id: PRIYA_ID, item_description: message,
      estimated_price: data.context?.estimated_price || null,
      ai_response: JSON.stringify(data), verdict: data.verdict,
      monthly_spent_so_far: wantsSpent, monthly_remaining: remaining,
    });

    return NextResponse.json({ data, wantsSpent, remaining, wantsBudget });
  } catch (error: any) {
    console.error("Purchase check error:", error);
    return NextResponse.json({ error: error.message }, { status: 500 });
  }
}

function extractJSON(text: string): string {
  const cb = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (cb) return cb[1].trim();
  const raw = text.match(/\{[\s\S]*\}/);
  if (raw) return raw[0];
  return text;
}
EOF

# ─── Seed script ──────────────────────────────────────────────
cat > peel/src/scripts/seed.ts << 'EOF'
import { createClient } from "@supabase/supabase-js";

const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE_KEY!);
const P = "00000000-0000-0000-0000-000000000001";

async function seed() {
  console.log("🌱 Seeding...\n");

  await supabase.from("purchase_checks").delete().neq("id","");
  await supabase.from("savings_goals").delete().neq("id","");
  await supabase.from("executed_actions").delete().neq("id","");
  await supabase.from("agent_activity").delete().neq("id","");
  await supabase.from("insights").delete().neq("id","");
  await supabase.from("scanned_receipts").delete().neq("id","");
  await supabase.from("transactions").delete().neq("id","");
  await supabase.from("accounts").delete().neq("id","");
  await supabase.from("user_profiles").delete().neq("id","");
  console.log("  ✓ Cleared");

  await supabase.from("user_profiles").insert({
    id: P, name: "Priya", age: 27, occupation: "Junior Product Manager",
    salary: 72000, freelance_ytd: 7500, tfsa_contributed_ytd: 2800, tfsa_limit: 7000, rrsp_room: 12960,
    rewards_categories: ["groceries","gas","restaurants"], goals: ["Max TFSA","Japan trip","Emergency fund"],
    monthly_needs_budget: 2560, monthly_wants_budget: 1540,
  });
  console.log("  ✓ Profile");

  await supabase.from("accounts").insert([
    { user_id: P, name: "Chequing", account_type: "chequing", balance: 4280, institution: "Tangerine" },
    { user_id: P, name: "Savings", account_type: "savings", balance: 11450, institution: "Tangerine" },
    { user_id: P, name: "TFSA", account_type: "tfsa", balance: 18300, institution: "Tangerine" },
    { user_id: P, name: "Visa Infinite", account_type: "credit", balance: -1870, institution: "TD" },
  ]);
  console.log("  ✓ Accounts");

  await supabase.from("savings_goals").insert([
    { user_id: P, name: "Japan Trip 🇯🇵", target_amount: 5000, current_amount: 1200, target_date: "2027-03-01", monthly_contribution: 200, priority: 1 },
    { user_id: P, name: "Emergency Fund 🛟", target_amount: 15000, current_amount: 11450, monthly_contribution: 300, priority: 2 },
  ]);
  console.log("  ✓ Goals");

  const t = (d:string,v:string,a:number,c:string,ty:string,ac:string,r:boolean,b:boolean,s:string) =>
    ({user_id:P,date:d,vendor:v,amount:a,category:c,tx_type:ty,account_name:ac,is_recurring:r,is_business:b,spend_type:s});

  const txns = [
    t("2025-12-01","Landlord - 45 Charles St",2100,"Rent","debit","Chequing",true,false,"need"),
    t("2025-12-02","Loblaws",87.43,"Groceries","debit","Chequing",false,false,"need"),
    t("2025-12-03","Netflix",16.49,"Subscriptions","debit","Visa",true,false,"want"),
    t("2025-12-03","Spotify",11.99,"Subscriptions","debit","Visa",true,false,"want"),
    t("2025-12-03","Adobe Creative Cloud",29.99,"Subscriptions","debit","Visa",true,true,"want"),
    t("2025-12-03","ClassPass",49.00,"Subscriptions","debit","Visa",true,false,"want"),
    t("2025-12-03","Crave",9.99,"Subscriptions","debit","Visa",true,false,"want"),
    t("2025-12-05","PixelWorks Design Co.",2500,"Freelance Income","credit","Chequing",false,true,"income"),
    t("2025-12-07","Uber",23.45,"Transportation","debit","Visa",false,false,"want"),
    t("2025-12-10","No Frills",62.17,"Groceries","debit","Chequing",false,false,"need"),
    t("2025-12-12","Shell",65.00,"Gas","debit","Visa",false,false,"need"),
    t("2025-12-14","Pai Northern Thai",47.80,"Restaurants","debit","Visa",false,false,"want"),
    t("2025-12-15","Tangerine TFSA",400,"Savings","debit","Chequing",false,false,"savings"),
    t("2025-12-18","Staples",89.99,"Office Supplies","debit","Visa",false,true,"want"),
    t("2025-12-20","Hydro One",78.43,"Utilities","debit","Chequing",true,false,"need"),
    t("2025-12-20","Rogers",85.00,"Phone/Internet","debit","Chequing",true,false,"need"),
    t("2025-12-22","Loblaws",94.21,"Groceries","debit","Chequing",false,false,"need"),
    t("2025-12-28","Uber Eats",38.90,"Restaurants","debit","Visa",false,false,"want"),
    t("2026-01-01","Landlord - 45 Charles St",2100,"Rent","debit","Chequing",true,false,"need"),
    t("2026-01-03","Netflix",16.49,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-01-03","Spotify",11.99,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-01-03","Adobe Creative Cloud",29.99,"Subscriptions","debit","Visa",true,true,"want"),
    t("2026-01-03","ClassPass",49.00,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-01-03","Crave",9.99,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-01-06","Loblaws",76.88,"Groceries","debit","Chequing",false,false,"need"),
    t("2026-01-08","Uber",18.70,"Transportation","debit","Visa",false,false,"want"),
    t("2026-01-10","PixelWorks Design Co.",1800,"Freelance Income","credit","Chequing",false,true,"income"),
    t("2026-01-12","Best Buy",149.99,"Equipment","debit","Visa",false,true,"want"),
    t("2026-01-15","Tangerine TFSA",400,"Savings","debit","Chequing",false,false,"savings"),
    t("2026-01-18","Shell",58.50,"Gas","debit","Visa",false,false,"need"),
    t("2026-01-20","Hydro One",82.10,"Utilities","debit","Chequing",true,false,"need"),
    t("2026-01-20","Rogers",85.00,"Phone/Internet","debit","Chequing",true,false,"need"),
    t("2026-01-22","No Frills",54.32,"Groceries","debit","Chequing",false,false,"need"),
    t("2026-01-25","Kinka Izakaya",62.40,"Restaurants","debit","Visa",false,false,"want"),
    t("2026-02-01","Landlord - 45 Charles St",2100,"Rent","debit","Chequing",true,false,"need"),
    t("2026-02-03","Netflix",16.49,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-02-03","Spotify",11.99,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-02-03","Adobe Creative Cloud",29.99,"Subscriptions","debit","Visa",true,true,"want"),
    t("2026-02-03","ClassPass",49.00,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-02-03","Crave",9.99,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-02-05","Loblaws",91.03,"Groceries","debit","Chequing",false,false,"need"),
    t("2026-02-14","Gusto 101",78.50,"Restaurants","debit","Visa",false,false,"want"),
    t("2026-02-15","Tangerine TFSA",400,"Savings","debit","Chequing",false,false,"savings"),
    t("2026-02-18","Shell",61.00,"Gas","debit","Visa",false,false,"need"),
    t("2026-02-20","Hydro One",75.90,"Utilities","debit","Chequing",true,false,"need"),
    t("2026-02-20","Rogers",85.00,"Phone/Internet","debit","Chequing",true,false,"need"),
    t("2026-02-22","PixelWorks Design Co.",3200,"Freelance Income","credit","Chequing",false,true,"income"),
    t("2026-03-01","Landlord - 45 Charles St",2100,"Rent","debit","Chequing",true,false,"need"),
    t("2026-03-03","Netflix",16.49,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-03-03","Spotify",11.99,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-03-03","Adobe Creative Cloud",29.99,"Subscriptions","debit","Visa",true,true,"want"),
    t("2026-03-03","ClassPass",49.00,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-03-03","Crave",9.99,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-03-06","No Frills",68.44,"Groceries","debit","Chequing",false,false,"need"),
    t("2026-03-12","Staples",45.67,"Office Supplies","debit","Visa",false,true,"want"),
    t("2026-03-15","Tangerine TFSA",400,"Savings","debit","Chequing",false,false,"savings"),
    t("2026-03-18","Shell",72.00,"Gas","debit","Visa",false,false,"need"),
    t("2026-03-20","Hydro One",71.20,"Utilities","debit","Chequing",true,false,"need"),
    t("2026-03-20","Rogers",85.00,"Phone/Internet","debit","Chequing",true,false,"need"),
    t("2026-03-25","Ramen Isshin",34.50,"Restaurants","debit","Visa",false,false,"want"),
    t("2026-04-01","Landlord - 45 Charles St",2100,"Rent","debit","Chequing",true,false,"need"),
    t("2026-04-03","Netflix",16.49,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-04-03","Spotify",11.99,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-04-03","Adobe Creative Cloud",29.99,"Subscriptions","debit","Visa",true,true,"want"),
    t("2026-04-03","ClassPass",49.00,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-04-03","Crave",9.99,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-04-05","Loblaws",79.55,"Groceries","debit","Chequing",false,false,"need"),
    t("2026-04-08","Uber",42.10,"Transportation","debit","Visa",false,false,"want"),
    t("2026-04-15","Tangerine TFSA",400,"Savings","debit","Chequing",false,false,"savings"),
    t("2026-04-18","Shell",59.00,"Gas","debit","Visa",false,false,"need"),
    t("2026-04-20","Hydro One",68.50,"Utilities","debit","Chequing",true,false,"need"),
    t("2026-04-20","Rogers",85.00,"Phone/Internet","debit","Chequing",true,false,"need"),
    t("2026-05-01","Landlord - 45 Charles St",2100,"Rent","debit","Chequing",true,false,"need"),
    t("2026-05-03","Netflix",16.49,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-05-03","Spotify",11.99,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-05-03","Adobe Creative Cloud",29.99,"Subscriptions","debit","Visa",true,true,"want"),
    t("2026-05-03","ClassPass",49.00,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-05-03","Crave",9.99,"Subscriptions","debit","Visa",true,false,"want"),
    t("2026-05-06","Loblaws",92.30,"Groceries","debit","Chequing",false,false,"need"),
    t("2026-05-10","PixelWorks Design Co.",1500,"Freelance Income","credit","Chequing",false,true,"income"),
    t("2026-05-15","Tangerine TFSA",400,"Savings","debit","Chequing",false,false,"savings"),
    t("2026-05-18","Shell",63.50,"Gas","debit","Visa",false,false,"need"),
    t("2026-05-20","Hydro One",74.80,"Utilities","debit","Chequing",true,false,"need"),
    t("2026-05-20","Rogers",85.00,"Phone/Internet","debit","Chequing",true,false,"need"),
    t("2026-05-22","No Frills",61.45,"Groceries","debit","Chequing",false,false,"need"),
  ];

  for (let i = 0; i < txns.length; i += 30) {
    await supabase.from("transactions").insert(txns.slice(i, i + 30));
  }
  console.log("  ✓ " + txns.length + " transactions");
  console.log("\n✅ Done! ID: " + P);
}

seed().catch(console.error);
EOF

echo ""
echo "✅ Part 1 complete!"
echo "   Now run: bash peel-setup-2.sh"
