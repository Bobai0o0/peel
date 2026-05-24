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
