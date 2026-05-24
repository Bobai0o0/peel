#!/bin/bash
# ============================================================
# PEEL SETUP — Part 2 of 2
# Creates page.tsx (the main UI)
# Run AFTER: bash peel-setup-1.sh
# ============================================================

echo "🍊 Creating page.tsx..."

cat > peel/src/app/page.tsx << 'ENDOFPAGE'
"use client";

import { useState, useRef, useCallback, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { createClient } from "@supabase/supabase-js";
import {
  Camera, Sparkles, X, Zap, Eye, ChevronUp, ChevronDown,
  RefreshCw, ArrowUp, TrendingUp, Wallet, PiggyBank, CheckCircle2, Send,
} from "lucide-react";

const supabase = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);
const PRIYA_ID = "00000000-0000-0000-0000-000000000001";

interface Account { name: string; account_type: string; balance: number; institution: string; }
interface ActivityEntry { agent: string; icon: string; message: string; }
interface ChatMessage {
  id: string; sender: "peel" | "user" | "system"; text: string;
  emoji?: string; type?: string; insight_data?: any; learn_card?: any;
}

function NotificationOverlay({ onOpen }: { onOpen: () => void }) {
  return (
    <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }}
      className="fixed inset-0 z-50 flex flex-col items-center justify-center p-6"
      style={{ background: "radial-gradient(circle at 50% 40%, rgba(245,130,32,0.08) 0%, #0A0A0F 70%)" }}>
      <motion.div initial={{ scale: 0 }} animate={{ scale: 1 }} transition={{ delay: 0.2, type: "spring", stiffness: 200 }}
        className="w-20 h-20 rounded-full bg-gradient-to-br from-tangerine-400 to-tangerine-600 flex items-center justify-center mb-8 glow-lg notif-pulse">
        <span className="text-3xl">🍊</span>
      </motion.div>
      <motion.h1 initial={{ y: 20, opacity: 0 }} animate={{ y: 0, opacity: 1 }} transition={{ delay: 0.5 }}
        className="text-3xl font-black text-center mb-2 gradient-text">Peel</motion.h1>
      <motion.p initial={{ y: 20, opacity: 0 }} animate={{ y: 0, opacity: 1 }} transition={{ delay: 0.7 }}
        className="text-gray-400 text-center text-sm mb-8">your AI financial copilot</motion.p>
      <motion.div initial={{ y: 30, opacity: 0 }} animate={{ y: 0, opacity: 1 }} transition={{ delay: 1, type: "spring" }}
        className="w-full max-w-sm glass-bright rounded-2xl p-5 glow-sm">
        <div className="flex items-center gap-3 mb-3">
          <div className="w-9 h-9 rounded-full bg-gradient-to-br from-tangerine-400 to-tangerine-600 flex items-center justify-center">
            <span className="text-sm">🍊</span></div>
          <div className="flex-1"><p className="text-xs text-gray-400">Peel</p>
            <p className="text-sm font-medium text-white">New insights</p></div>
          <span className="text-xs text-gray-600">now</span>
        </div>
        <p className="text-white text-[15px] leading-relaxed mb-4">
          hey priya 👋 i just found <span className="font-bold text-tangerine-400">$1,027/year</span> you&apos;re leaving on the table. wanna see?</p>
        <button onClick={onOpen} className="w-full py-3.5 bg-gradient-to-r from-tangerine-500 to-tangerine-600 text-white font-semibold rounded-xl glow-sm active:scale-[0.98]">show me →</button>
      </motion.div>
    </motion.div>
  );
}

function TypingIndicator() {
  return (
    <div className="flex items-center gap-1.5 px-4 py-3">
      <div className="w-7 h-7 rounded-full bg-gradient-to-br from-tangerine-400/80 to-tangerine-600/80 flex items-center justify-center">
        <span className="text-xs">🍊</span></div>
      <div className="glass rounded-2xl px-4 py-2.5 flex items-center gap-1">
        <div className="w-2 h-2 bg-tangerine-400 rounded-full typing-dot" />
        <div className="w-2 h-2 bg-tangerine-400 rounded-full typing-dot" />
        <div className="w-2 h-2 bg-tangerine-400 rounded-full typing-dot" />
      </div>
    </div>
  );
}

function ChatBubble({ message, index }: { message: ChatMessage; index: number }) {
  const [learnOpen, setLearnOpen] = useState(false);

  if (message.sender === "user") {
    return (
      <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} className="flex justify-end px-4 py-1">
        <div className="bubble-user bg-tangerine-500 px-4 py-2.5 max-w-[80%]">
          <p className="text-white text-[15px]">{message.text}</p></div>
      </motion.div>
    );
  }
  if (message.sender === "system") {
    return (
      <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="flex justify-center px-4 py-2">
        <span className="text-xs text-gray-600 glass rounded-full px-3 py-1">{message.text}</span>
      </motion.div>
    );
  }
  return (
    <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }}
      transition={{ delay: index * 0.05, type: "spring", stiffness: 300, damping: 30 }} className="px-4 py-1">
      <div className="flex items-end gap-2 max-w-[88%]">
        <div className="w-7 h-7 rounded-full bg-gradient-to-br from-tangerine-400/80 to-tangerine-600/80 flex items-center justify-center flex-shrink-0 mb-0.5">
          <span className="text-xs">🍊</span></div>
        <div className="flex-1 space-y-1.5">
          <div className="bubble-ai glass-bright px-4 py-3">
            <p className="text-[15px] text-gray-100 leading-relaxed">{message.text}</p>
            {message.insight_data?.annual_value > 0 && (
              <div className="mt-2 flex items-center gap-2">
                <span className="px-2.5 py-1 rounded-lg bg-tangerine-500/15 text-tangerine-400 text-xs font-bold">+${message.insight_data.annual_value.toLocaleString()}/yr</span>
              </div>
            )}
          </div>
          {message.learn_card && (
            <div>
              <button onClick={() => setLearnOpen(!learnOpen)}
                className="flex items-center gap-2 px-3 py-2 rounded-xl bg-blue-500/10 border border-blue-500/20 text-blue-400 text-xs font-medium w-full text-left">
                <span>💡</span><span className="flex-1">{message.learn_card.title}</span>
                {learnOpen ? <ChevronUp size={12} /> : <ChevronDown size={12} />}
              </button>
              <AnimatePresence>
                {learnOpen && (
                  <motion.div initial={{ opacity: 0, height: 0 }} animate={{ opacity: 1, height: "auto" }} exit={{ opacity: 0, height: 0 }}
                    className="glass rounded-xl p-3.5 mt-1.5 space-y-2">
                    <p className="text-sm text-gray-300 leading-relaxed">{message.learn_card.explanation}</p>
                    <div className="flex items-start gap-2 bg-tangerine-500/10 rounded-lg p-2.5">
                      <span className="text-xs">🎯</span>
                      <p className="text-xs text-tangerine-300">{message.learn_card.pro_tip}</p>
                    </div>
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
          )}
        </div>
      </div>
    </motion.div>
  );
}

function ReceiptBubble({ receipt }: { receipt: any }) {
  return (
    <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} className="px-4 py-1">
      <div className="flex items-end gap-2 max-w-[88%]">
        <div className="w-7 h-7 rounded-full bg-gradient-to-br from-tangerine-400/80 to-tangerine-600/80 flex items-center justify-center flex-shrink-0 mb-0.5">
          <span className="text-xs">🍊</span></div>
        <div className="bubble-ai glass-bright px-4 py-3 flex-1">
          <div className="flex items-center justify-between mb-2">
            <span className="font-semibold text-white text-sm">{receipt.vendor_name}</span>
            <span className="text-lg font-bold text-tangerine-400">${receipt.total_amount?.toFixed(2)}</span>
          </div>
          <div className="flex flex-wrap gap-1.5">
            <span className="px-2 py-0.5 rounded-md bg-tangerine-500/15 text-tangerine-300 text-[11px] font-medium">{receipt.category}</span>
            <span className="px-2 py-0.5 rounded-md bg-purple-500/15 text-purple-300 text-[11px] font-medium">{receipt.spend_type || "want"}</span>
            {receipt.is_business_expense && <span className="px-2 py-0.5 rounded-md bg-green-500/15 text-green-400 text-[11px] font-medium">✓ {receipt.cra_form}</span>}
            {receipt.gst_hst_amount > 0 && <span className="px-2 py-0.5 rounded-md bg-blue-500/15 text-blue-400 text-[11px] font-medium">HST ${receipt.gst_hst_amount?.toFixed(2)}</span>}
          </div>
        </div>
      </div>
    </motion.div>
  );
}

function AgentStrip({ entries, isOpen, onToggle }: { entries: ActivityEntry[]; isOpen: boolean; onToggle: () => void }) {
  return (
    <AnimatePresence>
      {isOpen && (
        <motion.div initial={{ y: "100%" }} animate={{ y: 0 }} exit={{ y: "100%" }} transition={{ type: "spring", damping: 25 }}
          className="fixed inset-x-0 bottom-0 z-40 glass rounded-t-2xl max-h-[45vh] overflow-hidden flex flex-col max-w-md mx-auto border-t border-white/10">
          <div className="flex items-center justify-between p-3.5 border-b border-white/5">
            <h3 className="text-[10px] font-bold text-gray-500 uppercase tracking-widest flex items-center gap-1.5">
              <Zap size={10} className="text-tangerine-400" /> Agent Activity</h3>
            <button onClick={onToggle} className="text-gray-600"><X size={16} /></button>
          </div>
          <div className="overflow-y-auto p-3.5 scroll-area">
            {entries.map((e, i) => (
              <motion.div key={i} initial={{ opacity: 0, x: -8 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: i * 0.08 }}
                className="flex items-start gap-2.5 mb-2.5">
                <span className="text-base mt-0.5">{e.icon}</span>
                <div><span className="text-[9px] font-bold uppercase tracking-widest text-gray-600">{e.agent}</span>
                  <p className="text-xs text-gray-400">{e.message}</p></div>
              </motion.div>
            ))}
          </div>
        </motion.div>
      )}
    </AnimatePresence>
  );
}

function HealthRing({ score }: { score: number }) {
  const c = 2 * Math.PI * 45;
  const o = c - (score / 100) * c;
  const color = score >= 70 ? "#22c55e" : score >= 50 ? "#F58220" : "#ef4444";
  return (
    <div className="relative w-28 h-28 flex items-center justify-center">
      <svg width="112" height="112" className="-rotate-90">
        <circle cx="56" cy="56" r="45" stroke="rgba(255,255,255,0.05)" strokeWidth="8" fill="none" />
        <motion.circle cx="56" cy="56" r="45" stroke={color} strokeWidth="8" fill="none" strokeLinecap="round"
          initial={{ strokeDashoffset: c }} animate={{ strokeDashoffset: o }}
          transition={{ duration: 1.5, ease: "easeOut", delay: 0.3 }} strokeDasharray={c} />
      </svg>
      <div className="absolute inset-0 flex flex-col items-center justify-center">
        <motion.span initial={{ opacity: 0 }} animate={{ opacity: 1 }} transition={{ delay: 0.8 }}
          className="text-2xl font-black tabular-nums" style={{ color }}>{score}</motion.span>
        <span className="text-[10px] text-gray-500 -mt-0.5">/ 100</span>
      </div>
    </div>
  );
}

export default function Home() {
  const [showNotif, setShowNotif] = useState(true);
  const [stripOpen, setStripOpen] = useState(false);
  const [actLog, setActLog] = useState<ActivityEntry[]>([]);
  const [msgs, setMsgs] = useState<ChatMessage[]>([]);
  const [accounts, setAccounts] = useState<Account[]>([]);
  const [receipt, setReceipt] = useState<any>(null);
  const [typing, setTyping] = useState(false);
  const [executing, setExecuting] = useState(false);
  const [done, setDone] = useState(false);
  const [showDash, setShowDash] = useState(true);
  const [health, setHealth] = useState(62);
  const [chatInput, setChatInput] = useState("");
  const chatEnd = useRef<HTMLDivElement>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  useEffect(() => { chatEnd.current?.scrollIntoView({ behavior: "smooth" }); }, [msgs, typing]);

  useEffect(() => {
    async function load() {
      const { data } = await supabase.from("accounts").select("name, account_type, balance, institution").eq("user_id", PRIYA_ID);
      if (data) setAccounts(data);
    }
    load();
    const ch = supabase.channel("acc").on("postgres_changes", { event: "UPDATE", schema: "public", table: "accounts" }, (p) => {
      setAccounts((prev) => prev.map((a) => a.name === p.new.name ? { ...a, balance: p.new.balance } : a));
    }).subscribe();
    return () => { supabase.removeChannel(ch); };
  }, []);

  const total = accounts.reduce((s, a) => s + a.balance, 0);

  const addPeel = useCallback(async (msg: any) => {
    setTyping(true);
    await new Promise((r) => setTimeout(r, 600 + Math.random() * 800));
    setTyping(false);
    setMsgs((p) => [...p, { ...msg, id: crypto.randomUUID(), sender: "peel" }]);
  }, []);

  const handleScan = useCallback(async (file: File) => {
    setShowDash(false);
    setMsgs((p) => [...p, { id: crypto.randomUUID(), sender: "user", text: "📷 [receipt]" }]);
    setTyping(true); setStripOpen(true);
    setActLog([{ agent: "watcher", icon: "👁️", message: "Scanning receipt..." }]);
    const reader = new FileReader();
    reader.onload = async () => {
      try {
        const res = await fetch("/api/receipt", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ image: reader.result }) });
        const data = await res.json();
        setTyping(false);
        if (data.receipt) {
          setReceipt(data.receipt);
          for (const e of data.activityLog || []) { await new Promise((r) => setTimeout(r, 400)); setActLog((p) => [...p, e]); }
          if (data.analysis?.messages) { for (const m of data.analysis.messages) await addPeel({ text: m.text, emoji: m.emoji, type: m.type }); }
          else { await addPeel({ text: `got it — $${data.receipt.total_amount?.toFixed(2)} at ${data.receipt.vendor_name}, tagged as ${data.receipt.category.toLowerCase()} ${data.receipt.is_business_expense ? "for your freelance biz 📎" : ""}` }); }
        }
      } catch { setTyping(false); await addPeel({ text: "couldn't read that receipt. try another? 📸" }); }
    };
    reader.readAsDataURL(file);
  }, [addPeel]);

  const handleInsights = useCallback(async () => {
    setShowDash(false); setStripOpen(true);
    setActLog([{ agent: "orchestrator", icon: "🔄", message: "Starting analysis..." }]);
    setMsgs((p) => [...p, { id: crypto.randomUUID(), sender: "system", text: "peel is analyzing your finances..." }]);
    setTyping(true);
    try {
      const res = await fetch("/api/insights", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({}) });
      const data = await res.json();
      setTyping(false);
      for (const e of data.activityLog || []) { await new Promise((r) => setTimeout(r, 300)); setActLog((p) => [...p, e]); }
      for (const m of data.data?.messages || []) await addPeel({ text: m.text, emoji: m.emoji, type: m.type, insight_data: m.insight_data, learn_card: m.learn_card });
    } catch { setTyping(false); await addPeel({ text: "something went wrong. try again?" }); }
  }, [addPeel]);

  const handleFix = useCallback(async () => {
    setExecuting(true);
    setMsgs((p) => [...p, { id: crypto.randomUUID(), sender: "user", text: "go 🚀" }]);
    setTyping(true);
    try {
      const res = await fetch("/api/execute", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ actions: null }) });
      const data = await res.json();
      setTyping(false);
      for (const m of data.execution?.execution_messages || []) await addPeel({ text: m.text, emoji: m.emoji, type: "execution" });
      for (const s of data.execution?.execution_steps || []) { await new Promise((r) => setTimeout(r, s.delay_ms || 600)); setActLog((p) => [...p, { agent: "doer", icon: "⚡", message: s.display_message }]); }
      if (data.updatedAccounts) setAccounts(data.updatedAccounts);
      if (data.execution?.completion_message) await addPeel({ text: data.execution.completion_message, type: "completion" });
      setHealth(78); setDone(true);
      await new Promise((r) => setTimeout(r, 2000));
      await addPeel({ text: "i'll check in next month with an update on how much you've saved. keep snapping those receipts 📸", type: "followup" });
    } catch { setTyping(false); await addPeel({ text: "execution failed. try again?" }); }
    setExecuting(false);
  }, [addPeel]);

  const handlePurchaseCheck = useCallback(async (text: string) => {
    setShowDash(false);
    setMsgs((p) => [...p, { id: crypto.randomUUID(), sender: "user", text }]);
    setTyping(true); setStripOpen(true);
    setActLog((p) => [...p, { agent: "thinker", icon: "🧠", message: "Checking budget..." }]);
    try {
      const res = await fetch("/api/purchase-check", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ message: text }) });
      const data = await res.json();
      setTyping(false);
      setActLog((p) => [...p, { agent: "thinker", icon: "🧠", message: `Wants spent: $${data.wantsSpent?.toFixed(0)} / $${data.wantsBudget}` }]);
      for (const m of data.data?.messages || []) await addPeel({ text: m.text, emoji: m.emoji, type: "purchase_check" });
    } catch { setTyping(false); await addPeel({ text: "couldn't check that. try again?" }); }
  }, [addPeel]);

  const handleSend = useCallback(() => {
    if (!chatInput.trim()) return;
    const text = chatInput.trim();
    setChatInput("");
    const lower = text.toLowerCase();
    if (lower.includes("should i") || lower.includes("can i afford") || lower.includes("buy") || lower.includes("purchase") || lower.includes("worth it") || lower.includes("splurge")) {
      handlePurchaseCheck(text);
    } else if (lower.includes("insight") || lower.includes("analyze") || lower.includes("scan my")) {
      handleInsights();
    } else {
      handlePurchaseCheck(text);
    }
  }, [chatInput, handlePurchaseCheck, handleInsights]);

  const handleReset = useCallback(async () => {
    setMsgs([]); setReceipt(null); setDone(false); setActLog([]);
    setShowDash(true); setShowNotif(true); setHealth(62); setChatInput("");
    const { data } = await supabase.from("accounts").select("name, account_type, balance, institution").eq("user_id", PRIYA_ID);
    if (data) setAccounts(data);
  }, []);

  return (
    <div className="app-shell bg-[#0A0A0F] text-white flex flex-col max-w-md mx-auto relative">
      <AnimatePresence>{showNotif && <NotificationOverlay onOpen={() => setShowNotif(false)} />}</AnimatePresence>

      <div className="px-4 pt-11 pb-3 flex items-center justify-between border-b border-white/5">
        <div className="flex items-center gap-2.5">
          <div className="w-8 h-8 rounded-full bg-gradient-to-br from-tangerine-400 to-tangerine-600 flex items-center justify-center"><span className="text-sm">🍊</span></div>
          <div><span className="font-bold text-sm gradient-text">Peel</span><p className="text-[10px] text-gray-600 -mt-0.5">AI financial copilot</p></div>
        </div>
        <div className="flex items-center gap-2">
          <button onClick={handleReset} className="p-1.5 text-gray-600"><RefreshCw size={13} /></button>
          <button onClick={() => setStripOpen(!stripOpen)}
            className={`px-2.5 py-1 rounded-full text-[10px] font-semibold flex items-center gap-1 ${actLog.length > 0 ? "bg-tangerine-500/15 text-tangerine-400" : "glass text-gray-500"}`}>
            <Zap size={10} /> {actLog.length || "0"}</button>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto scroll-area pb-24">
        {showDash && (
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }} className="px-4 pt-4 pb-2">
            <div className="flex items-center gap-4 mb-4">
              <HealthRing score={health} />
              <div className="flex-1">
                <p className="text-[10px] text-gray-500 uppercase tracking-wider">net worth</p>
                <p className="text-2xl font-black tabular-nums">${total.toLocaleString("en-CA", { maximumFractionDigits: 0 })}</p>
                <div className="flex items-center gap-1 mt-1"><TrendingUp size={11} className="text-green-400" />
                  <span className="text-[11px] text-green-400 font-medium">+3.2% this month</span></div>
              </div>
            </div>
            <div className="flex gap-2 overflow-x-auto pb-2 scroll-area">
              {accounts.map((a, i) => (
                <motion.div key={i} initial={{ opacity: 0, x: 20 }} animate={{ opacity: 1, x: 0 }} transition={{ delay: i * 0.1 }}
                  className="glass rounded-xl px-3.5 py-2.5 flex-shrink-0 min-w-[140px]">
                  <div className="flex items-center gap-1.5 mb-1">
                    {a.account_type === "chequing" && <Wallet size={12} className="text-tangerine-400" />}
                    {a.account_type === "savings" && <PiggyBank size={12} className="text-blue-400" />}
                    {a.account_type === "tfsa" && <TrendingUp size={12} className="text-green-400" />}
                    {a.account_type === "credit" && <span className="text-xs">💳</span>}
                    <span className="text-[11px] text-gray-400">{a.name}</span>
                  </div>
                  <p className={`text-sm font-bold tabular-nums ${a.balance < 0 ? "text-red-400" : "text-white"}`}>
                    ${Math.abs(a.balance).toLocaleString("en-CA")}{a.balance < 0 ? " owing" : ""}</p>
                  <p className="text-[9px] text-gray-600">{a.institution}</p>
                </motion.div>
              ))}
            </div>
            <div className="grid grid-cols-2 gap-2.5 mt-3">
              <button onClick={() => fileRef.current?.click()} className="glass rounded-xl p-3 flex items-center gap-2.5 active:scale-[0.97]">
                <div className="w-9 h-9 rounded-lg bg-tangerine-500/15 flex items-center justify-center"><Camera size={18} className="text-tangerine-400" /></div>
                <div className="text-left"><p className="text-xs font-semibold">Scan Receipt</p><p className="text-[10px] text-gray-500">photo or upload</p></div>
              </button>
              <button onClick={handleInsights} className="glass rounded-xl p-3 flex items-center gap-2.5 active:scale-[0.97]">
                <div className="w-9 h-9 rounded-lg bg-purple-500/15 flex items-center justify-center"><Sparkles size={18} className="text-purple-400" /></div>
                <div className="text-left"><p className="text-xs font-semibold">Get Insights</p><p className="text-[10px] text-gray-500">AI analysis</p></div>
              </button>
            </div>
            {msgs.length === 0 && <p className="text-center mt-6 text-gray-600 text-xs">tap an action or ask peel anything below</p>}
          </motion.div>
        )}

        {!showDash && (
          <button onClick={() => setShowDash(true)} className="w-full py-2 text-center text-[10px] text-gray-600 glass border-b border-white/5 flex items-center justify-center gap-1">
            <ChevronDown size={10} /> show dashboard</button>
        )}

        {receipt && <ReceiptBubble receipt={receipt} />}
        {msgs.map((m, i) => <ChatBubble key={m.id} message={m} index={i} />)}

        {msgs.some((m) => m.type === "action_prompt") && !done && !executing && (
          <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} className="px-4 py-2">
            <button onClick={handleFix}
              className="w-full py-3.5 bg-gradient-to-r from-tangerine-500 to-tangerine-600 text-white font-bold rounded-xl text-sm flex items-center justify-center gap-2 glow-sm active:scale-[0.98]">
              <Zap size={16} /> fix all three — save $1,027/yr</button>
          </motion.div>
        )}

        {typing && <TypingIndicator />}
        <div ref={chatEnd} />
      </div>

      <div className="fixed bottom-0 inset-x-0 max-w-md mx-auto glass border-t border-white/5 px-3 py-3 flex items-center gap-2 z-30">
        <button onClick={() => fileRef.current?.click()} className="w-9 h-9 rounded-full glass flex items-center justify-center flex-shrink-0 active:scale-90">
          <Camera size={16} className="text-gray-400" /></button>
        <input value={chatInput} onChange={(e) => setChatInput(e.target.value)} onKeyDown={(e) => e.key === "Enter" && handleSend()}
          placeholder="ask peel anything..." className="flex-1 bg-transparent glass rounded-full px-4 py-2.5 text-sm text-white placeholder:text-gray-500 outline-none" />
        <button onClick={chatInput.trim() ? handleSend : handleInsights}
          className="w-9 h-9 rounded-full bg-gradient-to-br from-tangerine-500 to-tangerine-600 flex items-center justify-center flex-shrink-0 glow-sm active:scale-90">
          {chatInput.trim() ? <Send size={14} className="text-white" /> : <ArrowUp size={16} className="text-white" />}</button>
      </div>

      <input ref={fileRef} type="file" accept="image/*" className="hidden"
        onChange={(e) => { const f = e.target.files?.[0]; if (f) handleScan(f); }} />

      <AgentStrip entries={actLog} isOpen={stripOpen} onToggle={() => setStripOpen(false)} />
    </div>
  );
}
ENDOFPAGE

echo ""
echo "✅ Part 2 complete! All files created."
echo ""
echo "Next steps:"
echo "  1. cd peel"
echo "  2. cp .env.local.example .env.local"
echo "  3. Edit .env.local with your Gemini + Supabase keys"
echo "  4. Paste supabase/schema.sql into Supabase SQL Editor → Run"
echo "  5. npm install"
echo "  6. npm run seed"
echo "  7. npm run dev"
echo "  8. Open http://localhost:3000"
echo ""
echo "🍊 Go win this thing!"
