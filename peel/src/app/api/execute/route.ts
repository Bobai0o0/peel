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
