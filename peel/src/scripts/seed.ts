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
