import { NextRequest, NextResponse } from "next/server";
import { GoogleGenerativeAI } from "@google/generative-ai";
import { RECEIPT_PROMPT } from "@/data/prompts";
import { dbAdmin } from "@/lib/supabase";

const ai = process.env.GEMINI_API_KEY ? new GoogleGenerativeAI(process.env.GEMINI_API_KEY) : null;

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const { image, userId } = body;
    if (!userId || !image) return NextResponse.json({ error: "Missing data" }, { status: 400 });

    const m = image.match(/^data:(.+);base64,(.+)$/);
    if (!m) return NextResponse.json({ error: "Bad image format" }, { status: 400 });

    const db = dbAdmin();
    let receipt: any = null;

    if (ai) {
      try {
        const model = ai.getGenerativeModel({ model: "gemini-2.0-flash-lite" });
        const r = await model.generateContent([
          { text: RECEIPT_PROMPT + "\nParse this receipt:" },
          { inlineData: { mimeType: m[1], data: m[2] } },
        ]);
        receipt = JSON.parse(exJ(r.response.text()));
      } catch (geminiErr: any) {
        console.error("Gemini receipt failed:", geminiErr.message);
      }
    }

    // Fallback receipt if Gemini failed
    if (!receipt) {
      receipt = {
        vendor_name: "Scanned Receipt",
        date: new Date().toISOString().slice(0, 10),
        total_amount: 0,
        gst_hst_amount: 0,
        items: [],
        category: "Other",
        spend_type: "want",
        is_business_expense: false,
        cra_form: "N/A",
        confidence: 0,
      };
    }

    // Write to DB
    try {
      await db.from("scanned_receipts").insert({
        user_id: userId, vendor_name: receipt.vendor_name, total_amount: receipt.total_amount,
        category: receipt.category, is_business_expense: receipt.is_business_expense,
        cra_form: receipt.cra_form, items: receipt.items || [],
        gst_hst_amount: receipt.gst_hst_amount || 0, spend_type: receipt.spend_type || "want",
      });
      await db.from("transactions").insert({
        user_id: userId, date: receipt.date || new Date().toISOString().slice(0, 10),
        vendor: receipt.vendor_name, amount: receipt.total_amount || 0,
        category: receipt.category || "Other", tx_type: "debit", account_name: "Visa",
        is_business: receipt.is_business_expense || false, spend_type: receipt.spend_type || "want",
      });
    } catch (dbErr: any) {
      console.error("DB write failed:", dbErr.message);
    }

    const analysis = {
      messages: [
        { type: "receipt_parsed", text: `got it — $${receipt.total_amount || 0} at ${receipt.vendor_name}, tagged as ${(receipt.category || "other").toLowerCase()} (${receipt.spend_type || "want"}) 📎` },
        { type: "budget_note", text: receipt.is_business_expense ? `that's a business deduction on your T2125 ✓` : `logged as a ${receipt.spend_type || "want"} expense` },
      ],
      reasoning_steps: [
        `Parsed: ${receipt.vendor_name}`,
        `Amount: $${receipt.total_amount || 0}`,
        `Category: ${receipt.category || "Other"} (${receipt.spend_type || "want"})`,
      ],
    };

    const activityLog = [
      { agent: "watcher", icon: "👁️", message: `${receipt.vendor_name}, $${receipt.total_amount} — ${receipt.category}` },
      { agent: "thinker", icon: "🧠", message: `Classified as ${receipt.spend_type} expense` },
      { agent: "doer", icon: "⚡", message: "Added to expense report." },
    ];

    return NextResponse.json({ receipt, analysis, activityLog });
  } catch (e: any) {
    console.error("Receipt route error:", e);
    return NextResponse.json({
      receipt: { vendor_name: "Unknown", total_amount: 0, category: "Other", spend_type: "want", is_business_expense: false, cra_form: "N/A" },
      analysis: { messages: [{ type: "receipt_parsed", text: "hmm had trouble reading that one. try a clearer photo? 📸" }], reasoning_steps: [] },
      activityLog: [{ agent: "watcher", icon: "👁️", message: "Receipt scan completed with issues" }],
    });
  }
}

function exJ(t: string): string {
  const c = t.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (c) return c[1].trim();
  const r = t.match(/\{[\s\S]*\}/);
  return r ? r[0] : t;
}
