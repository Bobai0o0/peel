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
