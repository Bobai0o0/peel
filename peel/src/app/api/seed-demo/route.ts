// FILE: peel/src/app/api/seed-demo/route.ts

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
  const name = user.user_metadata?.name || user.email?.split("@")[0] || "User";

  try {
    // Use maybeSingle — returns null if no row, doesn't throw 406
    const { data: exists } = await db.from("user_profiles").select("id").eq("id", u).maybeSingle();
    if (exists) return NextResponse.json({ ok: true, existing: true });

    await db.from("user_profiles").insert({
      id: u, name, salary: 0, freelance_ytd: 0,
      tfsa_contributed_ytd: 0, tfsa_limit: 7000,
      rewards_categories: ["groceries", "gas", "restaurants"],
      monthly_wants_budget: 1540,
    });

    await db.from("accounts").insert([
      { user_id: u, name: "Chequing", account_type: "chequing", balance: 0, institution: "Tangerine" },
      { user_id: u, name: "Savings", account_type: "savings", balance: 0, institution: "Tangerine" },
      { user_id: u, name: "TFSA", account_type: "tfsa", balance: 0, institution: "Tangerine" },
    ]);

    return NextResponse.json({ ok: true, new: true });
  } catch (e: any) {
    console.error("Seed error:", e);
    return NextResponse.json({ ok: false, error: e.message }, { status: 500 });
  }
}
