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
