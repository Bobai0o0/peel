import { NextRequest, NextResponse } from "next/server";
import { dbAdmin } from "@/lib/supabase";

export async function POST(req: NextRequest) {
  try {
    const body = await req.json().catch(() => ({}));
    const { userId } = body;
    const db = dbAdmin();

    const receipt = {
      vendor_name: "Alo Yoga",
      date: new Date().toISOString().slice(0, 10),
      total_amount: 144.64,
      gst_hst_amount: 16.64,
      items: [
        { description: "Airlift Speedwork Bra - Black", amount: 128.00 },
      ],
      category: "Shopping",
      spend_type: "want",
      is_business_expense: false,
      cra_form: "N/A",
      confidence: 0.97,
    };

    if (userId) {
      try {
        await db.from("scanned_receipts").insert({
          user_id: userId, vendor_name: receipt.vendor_name, total_amount: receipt.total_amount,
          category: receipt.category, is_business_expense: receipt.is_business_expense,
          cra_form: receipt.cra_form, items: receipt.items, gst_hst_amount: receipt.gst_hst_amount,
          spend_type: receipt.spend_type,
        });
        await db.from("transactions").insert({
          user_id: userId, date: receipt.date, vendor: receipt.vendor_name,
          amount: receipt.total_amount, category: receipt.category, tx_type: "debit",
          account_name: "Visa", is_business: false, spend_type: "want",
        });
      } catch (e) {}
    }

    const analysis = {
      messages: [
        { type: "receipt_parsed", text: "got it — $144.64 at alo yoga. airlift speedwork bra, tagged as shopping (want) 🛍️" },
        { type: "budget_note", text: "that's $144.64 from your fun budget. you had $128 left this month, so this puts you $16.64 over. not the end of the world but worth knowing 💛" },
      ],
      reasoning_steps: [
        "Parsed 1 item: Airlift Speedwork Bra - Black",
        "Vendor: Alo Yoga — classified as Shopping",
        "Spend type: want (clothing / personal)",
        "HST: $16.64 (Ontario 13%)",
      ],
    };

    const activityLog = [
      { agent: "watcher", icon: "👁️", message: "Alo Yoga, $144.64 — Shopping" },
      { agent: "watcher", icon: "👁️", message: "1 item: Airlift Speedwork Bra - Black" },
      { agent: "thinker", icon: "🧠", message: "Classified as want (clothing)" },
      { agent: "thinker", icon: "🧠", message: "Fun budget: $128 remaining → now $16.64 over" },
      { agent: "doer", icon: "⚡", message: "Logged to transactions" },
    ];

    return NextResponse.json({ receipt, analysis, activityLog });
  } catch (e: any) {
    return NextResponse.json({
      receipt: { vendor_name: "Alo Yoga", total_amount: 144.64, category: "Shopping", spend_type: "want", is_business_expense: false, cra_form: "N/A" },
      analysis: { messages: [{ type: "receipt_parsed", text: "got it — $144.64 at alo yoga, shopping (want) 🛍️" }], reasoning_steps: [] },
      activityLog: [{ agent: "watcher", icon: "👁️", message: "Alo Yoga, $144.64" }],
    });
  }
}