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
