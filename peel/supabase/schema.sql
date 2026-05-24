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
