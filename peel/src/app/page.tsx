"use client";
import { useState, useRef, useEffect, useCallback } from "react";
import { createClient } from "@supabase/supabase-js";

const sb = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);

// ─── AUTH FORM ───────────────────────────────────────────────
function AuthForm() {
  const [email,setEmail]=useState(""); const [pass,setPass]=useState("");
  const [mode,setMode]=useState<"signup"|"login">("signup"); const [err,setErr]=useState("");
  const go=async()=>{setErr("");
    const {error}=mode==="signup"?await sb.auth.signUp({email,password:pass}):await sb.auth.signInWithPassword({email,password:pass});
    if(error)setErr(error.message);};
  return <div className="w-full max-w-sm mx-auto space-y-3">
    <input value={email} onChange={e=>setEmail(e.target.value)} placeholder="email" className="w-full px-4 py-3 border-2 border-dim-gray-400 rounded-2xl bg-white text-dim-gray-400 font-semibold outline-none focus:border-burnt-orange"/>
    <input value={pass} onChange={e=>setPass(e.target.value)} placeholder="password" type="password" className="w-full px-4 py-3 border-2 border-dim-gray-400 rounded-2xl bg-white text-dim-gray-400 font-semibold outline-none focus:border-burnt-orange"/>
    {err&&<p className="text-red-500 text-xs font-bold">{err}</p>}
    <button onClick={go} className="w-full bg-burnt-orange hover:bg-dim-gray-400 text-white font-black py-3 rounded-2xl border-b-4 border-black/30 transition-all">{mode==="signup"?"Sign Up":"Log In"}</button>
    <button onClick={()=>setMode(mode==="signup"?"login":"signup")} className="w-full text-sm text-dim-gray-500 font-bold">{mode==="signup"?"have an account? log in":"need an account? sign up"}</button>
  </div>;
}

// ─── LEARN CARD ──────────────────────────────────────────────
function LearnCard({card}:{card:any}){
  const [open,setOpen]=useState(false);
  return <div className="ml-12">
    <button onClick={()=>setOpen(!open)} className="text-xs font-black text-burnt-orange bg-floral-white border-2 border-burnt-orange/30 px-3 py-1.5 rounded-xl w-full text-left flex justify-between items-center">
      <span>💡 {card.title}</span><span>{open?"▲":"▼"}</span></button>
    {open&&<div className="bg-white border-2 border-white-smoke p-3 rounded-xl mt-1 text-xs text-dim-gray-500 font-medium space-y-2">
      <p>{card.explanation}</p>
      <p className="bg-floral-white p-2 rounded-lg text-burnt-orange font-bold">🎯 {card.pro_tip}</p>
    </div>}
  </div>;
}

// ─── MAIN ────────────────────────────────────────────────────
export default function Home() {
  const [session,setSession]=useState<any>(null);
  const [loading,setLoading]=useState(true);
  const [appOpen,setAppOpen]=useState(false);
  const [accounts,setAccounts]=useState<any[]>([]);
  const [msgs,setMsgs]=useState<any[]>([]);
  const [typing,setTyping]=useState(false);
  const [input,setInput]=useState("");
  const [done,setDone]=useState(false);
  const [agentLog,setAgentLog]=useState<any[]>([]);
  const [showAgents,setShowAgents]=useState(false);
  const [receipt,setReceipt]=useState<any>(null);
  const [score,setScore]=useState(62);
  const endRef=useRef<HTMLDivElement>(null);
  const fileRef=useRef<HTMLInputElement>(null);

  useEffect(()=>{
    sb.auth.getSession().then(({data:{session:s}})=>{setSession(s);setLoading(false)});
    const {data:{subscription}}=sb.auth.onAuthStateChange((_,s)=>setSession(s));
    return ()=>subscription.unsubscribe();
  },[]);

  useEffect(() => {
    if (!session) return;
    const uid = session.user.id;
    const name = session.user.email?.split("@")[0] || "User";

    // Ensure user profile exists (creates on first login, no-ops after)
    const init = async () => {
      const { data: existing } = await sb.from("user_profiles").select("id").eq("id", uid).single();
      if (!existing) {
        await fetch("/api/seed-demo", {
          method: "POST",
          headers: { "Authorization": "Bearer " + session.access_token },
        });
      }
      const { data: acc } = await sb.from("accounts").select("*").eq("user_id", uid);
      if (acc) setAccounts(acc);
    };
    init();

    const ch = sb.channel("a").on("postgres_changes", { event: "UPDATE", schema: "public", table: "accounts" }, p => {
      setAccounts(prev => prev.map(a => a.name === p.new.name ? { ...a, balance: p.new.balance } : a));
    }).subscribe();
    return () => { sb.removeChannel(ch) };
  }, [session]);

  useEffect(()=>{endRef.current?.scrollIntoView({behavior:"smooth"})},[msgs,typing]);

  const uid=session?.user?.id;
  const name=session?.user?.email?.split("@")[0]||"there";
  const total=accounts.reduce((s,a)=>s+a.balance,0);

  const addPeel=useCallback(async(text:string,extra?:any)=>{
    setTyping(true); await new Promise(r=>setTimeout(r,500+Math.random()*500)); setTyping(false);
    setMsgs(p=>[...p,{id:crypto.randomUUID(),from:"peel",text,...extra}]);
  },[]);

  const scanReceipt=async(file:File)=>{
    if(!uid)return;
    setMsgs(p=>[...p,{id:crypto.randomUUID(),from:"user",text:"📷 [receipt uploaded]"}]); setTyping(true);
    const reader=new FileReader(); reader.onload=async()=>{
      const res=await fetch("/api/receipt",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({image:reader.result,userId:uid})});
      const d=await res.json(); setTyping(false);
      if(d.receipt){setReceipt(d.receipt);setAgentLog(p=>[...p,...(d.activityLog||[])]);
        for(const m of d.analysis?.messages||[]) await addPeel(m.text);
        if(!d.analysis?.messages?.length) await addPeel(`got it — $${d.receipt.total_amount} at ${d.receipt.vendor_name}, ${d.receipt.category} (${d.receipt.spend_type})`);
      }
    }; reader.readAsDataURL(file);
  };

  const getInsights=async()=>{
    if(!uid)return;
    setMsgs(p=>[...p,{id:crypto.randomUUID(),from:"system",text:"peel is analyzing your finances..."}]); setTyping(true);
    const res=await fetch("/api/insights",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({userId:uid})});
    const d=await res.json(); setTyping(false);
    setAgentLog(p=>[...p,...(d.activityLog||[])]);
    for(const m of d.data?.messages||[]) await addPeel(m.text,{learnCard:m.learn_card,insightData:m.insight_data});
  };

  const fixAll=async()=>{
    if(!uid)return;
    setMsgs(p=>[...p,{id:crypto.randomUUID(),from:"user",text:"go 🚀"}]); setTyping(true);
    const res=await fetch("/api/execute",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({userId:uid})});
    const d=await res.json(); setTyping(false);
    for(const m of d.execution?.execution_messages||[]) await addPeel(m.text);
    if(d.execution?.completion_message) await addPeel(d.execution.completion_message);
    if(d.updatedAccounts) setAccounts(d.updatedAccounts);
    setScore(78); setDone(true);
    await new Promise(r=>setTimeout(r,1500));
    await addPeel("i'll check in next month with an update. keep snapping those receipts 📸");
  };

  const checkPurchase=async(text:string)=>{
    if(!uid)return;
    setMsgs(p=>[...p,{id:crypto.randomUUID(),from:"user",text}]); setTyping(true);
    const res=await fetch("/api/purchase-check",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({message:text,userId:uid})});
    const d=await res.json(); setTyping(false);
    for(const m of d.data?.messages||[]) await addPeel(m.text);
  };

  const send=()=>{if(!input.trim())return; const t=input.trim(); setInput("");
    const l=t.toLowerCase();
    if(l.includes("buy")||l.includes("should i")||l.includes("afford")||l.includes("worth")||l.includes("splurge")) checkPurchase(t);
    else if(l.includes("insight")||l.includes("analyze")) getInsights();
    else checkPurchase(t);
  };

  if(loading) return <div className="min-h-screen flex items-center justify-center"><p className="text-dark-gray font-bold">Loading...</p></div>;

  // ─── LANDING PAGE (not logged in or app not open) ──────────
  if(!session || !appOpen) return (
    <>
    {/* HEADER */}
    <header className="bg-white border-b-4 border-dim-gray-400 sticky top-0 z-50">
      <div className="max-w-7xl mx-auto px-6 h-24 flex items-center justify-between">
        <div className="flex items-center space-x-10">
          <a href="#" className="flex items-center space-x-3 group">
            <div className="relative w-9 h-9 flex items-end">
              <span className="absolute bottom-0 left-0 w-2.5 h-7 bg-burnt-orange rounded-full -rotate-12 origin-bottom"></span>
              <span className="absolute bottom-0 left-3.5 w-2.5 h-8 bg-burnt-orange rounded-full -rotate-6 origin-bottom"></span>
              <span className="absolute bottom-0 left-7 w-3 h-6 bg-burnt-orange rounded-full"></span>
            </div>
            <span className="text-3xl font-black tracking-tight text-burnt-orange">peel</span>
          </a>
          <nav className="hidden md:flex items-center space-x-6 text-base font-bold">
            <a href="#features" className="hover:text-burnt-orange px-2 py-1 rounded-lg transition-all">what it does</a>
            <a href="#pipeline" className="hover:text-burnt-orange px-2 py-1 rounded-lg transition-all">how it thinks</a>
          </nav>
        </div>
        <button onClick={()=>{if(session){setAppOpen(true)}else{document.getElementById("auth-section")?.scrollIntoView({behavior:"smooth"})}}} className="bg-burnt-orange hover:bg-dim-gray-400 text-white text-base font-black px-6 py-3 rounded-full border-b-4 border-black/30 transition-all transform hover:-translate-y-0.5 active:translate-y-1 shadow-sm">
          {session?"Open App":"Try For Free"}
        </button>
      </div>
    </header>

    <main className="space-y-12 py-12">
      {/* HERO */}
      <section className="max-w-7xl mx-auto px-6 grid lg:grid-cols-12 gap-8 items-center">
        <div className="lg:col-span-6 bg-white border-4 border-dim-gray-400 rounded-[32px] p-8 md:p-12 space-y-6 shadow-[8px_8px_0px_0px_rgba(58,56,53,1)]">
          <div className="inline-flex items-center gap-2 bg-white border-2 border-burnt-orange text-burnt-orange font-black text-xs px-3 py-1 rounded-full uppercase tracking-wider">
            Financial Literacy Made Simple
          </div>
          <h1 className="text-4xl md:text-5xl font-black text-dim-gray-300 tracking-tight leading-none">
            Money management done <span className="text-burnt-orange">for you.</span>
          </h1>
          <p className="text-base text-dim-gray-500 font-medium leading-relaxed">
            No complicated charts or spreadsheets. Just text Peel like a friend — our three AI agents handle tracking your spending, scanning receipts, checking if you can afford a purchase, and optimizing your savings. All for free.
          </p>
          <button onClick={()=>{if(session){setAppOpen(true)}else{document.getElementById("auth-section")?.scrollIntoView({behavior:"smooth"})}}} className="bg-dim-gray-400 hover:bg-dim-gray-300 text-white font-black text-base px-6 py-4 rounded-2xl border-b-4 border-black/30 transition-all">
            🍊 {session?"Open Peel":"Join In"}
          </button>
        </div>

        {/* Phone mockup (static) */}
        <div className="lg:col-span-6 flex justify-center">
          <div className="w-full max-w-[360px] bg-white border-4 border-dim-gray-400 rounded-[40px] p-4 shadow-[8px_8px_0px_0px_rgba(58,56,53,1)]">
            <div className="bg-burnt-orange rounded-[28px] p-4 flex flex-col justify-between min-h-[480px] text-white">
              <div className="flex justify-between items-center border-b-2 border-white/20 pb-3">
                <span className="text-xl font-black tracking-tight flex items-center gap-1.5">
                  <div className="relative w-5 h-5 flex items-end opacity-90">
                    <span className="absolute bottom-0 left-0 w-1.5 h-4 bg-white rounded-full -rotate-12 origin-bottom"></span>
                    <span className="absolute bottom-0 left-2 w-1.5 h-5 bg-white rounded-full -rotate-6 origin-bottom"></span>
                    <span className="absolute bottom-0 left-4 w-2 h-3 bg-white rounded-full"></span>
                  </div> peel
                </span>
                <span className="bg-white/20 border border-white/30 text-[11px] font-black px-3 py-1 rounded-full uppercase tracking-wider shadow-sm">62/100 SCORE</span>
              </div>
              <div className="flex-grow my-3 space-y-3 overflow-y-auto text-xs py-3 font-semibold">
                <div className="max-w-[92%]"><div className="bg-white text-dim-gray-400 border-2 border-dim-gray-400 p-3 rounded-2xl rounded-tl-none shadow-sm">
                  <p className="lowercase">hey priya! you&apos;ve got <span className="text-burnt-orange font-black">$128</span> left in your fun budget before the month ends 🛒</p></div></div>
                <div className="max-w-[92%]"><div className="bg-white text-dim-gray-400 border-2 border-dim-gray-400 p-3 rounded-2xl rounded-tl-none shadow-sm space-y-2">
                  <p className="lowercase">your japan trip fund is at <span className="text-burnt-orange font-black">24%</span>! you&apos;re doing great</p>
                  <div className="w-full bg-white-smoke h-3.5 rounded-full border-2 border-dim-gray-400 overflow-hidden"><div className="bg-burnt-orange h-full w-[24%] border-r-2 border-dim-gray-400"></div></div></div></div>
                <div className="max-w-[85%] ml-auto mt-2"><div className="bg-dim-gray-400 border-2 border-dim-gray-400 p-3 rounded-2xl rounded-tr-none text-right shadow-sm">
                  <p className="lowercase">should i buy these sneakers for $180?</p></div></div>
                <div className="max-w-[92%] mt-2"><div className="bg-floral-white text-dim-gray-400 border-2 border-dim-gray-400 p-3 rounded-2xl rounded-tl-none shadow-sm space-y-1.5">
                  <p className="text-[9px] uppercase tracking-wider text-burnt-orange font-black">🧠 thinker advisor verdict</p>
                  <p className="lowercase">that would put you <span className="text-burnt-orange font-black">$52</span> over your budget! screenshot them and wait till june?</p></div></div>
                <div className="bg-white/20 p-2 rounded-xl flex items-center space-x-1 w-10 justify-center">
                  <span className="w-1 h-1 bg-white rounded-full dot"></span><span className="w-1 h-1 bg-white rounded-full dot"></span><span className="w-1 h-1 bg-white rounded-full dot"></span></div>
              </div>
              <div className="bg-white/20 border border-white/30 p-2.5 rounded-xl flex justify-between items-center text-[11px] font-medium">
                <span className="pl-1">ask peel anything...</span><span>→</span></div>
            </div>
          </div>
        </div>
      </section>

      {/* FEATURES */}
      <section id="features" className="max-w-7xl mx-auto px-6">
        <div className="bg-white border-4 border-dim-gray-400 rounded-[32px] p-8 md:p-12 space-y-12 shadow-[8px_8px_0px_0px_rgba(58,56,53,1)]">
          <div className="max-w-2xl space-y-3">
            <span className="text-xs font-black text-burnt-orange uppercase tracking-widest">Platform Utilities</span>
            <h2 className="text-3xl md:text-4xl font-black text-dim-gray-300 tracking-tight">Five simple superpowers for your money.</h2>
          </div>
          <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-6">
            <div className="bg-ghost-white border-2 border-dim-gray-400 p-6 rounded-2xl space-y-3 hover:-translate-y-0.5 transition-all">
              <div className="w-12 h-12 bg-burnt-orange text-white rounded-xl border-2 border-dim-gray-400 flex items-center justify-center shadow-[3px_3px_0px_0px_rgba(58,56,53,1)] text-xl">📷</div>
              <h3 className="text-lg font-black text-dim-gray-300">Omni Receipt Scanning</h3>
              <p className="text-sm text-dim-gray-500 font-medium leading-relaxed">Snap paper bills, upload screenshots of online orders, or forward email receipts. Peel&apos;s Watcher agent parses vendor, amount, tax, and CRA category automatically.</p>
            </div>
            <div className="bg-ghost-white border-2 border-dim-gray-400 p-6 rounded-2xl space-y-3 hover:-translate-y-0.5 transition-all">
              <div className="w-12 h-12 bg-white text-burnt-orange rounded-xl border-2 border-dim-gray-400 flex items-center justify-center shadow-[3px_3px_0px_0px_rgba(58,56,53,1)] text-xl">📊</div>
              <h3 className="text-lg font-black text-dim-gray-300">Needs vs Wants Filter</h3>
              <p className="text-sm text-dim-gray-500 font-medium leading-relaxed">Every transaction sorted into 50/30/20. See exactly how much fun money you have left this month. No guesswork, no spreadsheets.</p>
              <div className="bg-white p-3 rounded-xl border-2 border-white-smoke space-y-1.5 text-xs font-bold">
                <div className="flex justify-between text-burnt-orange"><span>Fun Left</span><span>$128</span></div>
                <div className="w-full bg-white-smoke h-2 rounded-full overflow-hidden"><div className="bg-burnt-orange h-full w-[40%]"></div></div>
              </div>
            </div>
            <div className="bg-ghost-white border-2 border-dim-gray-400 p-6 rounded-2xl space-y-3 hover:-translate-y-0.5 transition-all">
              <div className="w-12 h-12 bg-white text-burnt-orange rounded-xl border-2 border-dim-gray-400 flex items-center justify-center shadow-[3px_3px_0px_0px_rgba(58,56,53,1)] text-xl">❓</div>
              <h3 className="text-lg font-black text-dim-gray-300">Pre-Purchase Advisor</h3>
              <p className="text-sm text-dim-gray-500 font-medium leading-relaxed">Text &ldquo;should I buy these sneakers for $180?&rdquo; and Peel checks your real budget and savings goals before you spend.</p>
            </div>
            <div className="bg-ghost-white border-2 border-dim-gray-400 p-6 rounded-2xl space-y-3 hover:-translate-y-0.5 transition-all">
              <div className="w-12 h-12 bg-white text-burnt-orange rounded-xl border-2 border-dim-gray-400 flex items-center justify-center shadow-[3px_3px_0px_0px_rgba(58,56,53,1)] text-xl">🎯</div>
              <h3 className="text-lg font-black text-dim-gray-300">Woven Savings Goals</h3>
              <p className="text-sm text-dim-gray-500 font-medium leading-relaxed">Japan trip, emergency fund, first car — goals are built into every interaction. The purchase advisor references them. The Doer allocates savings toward them.</p>
            </div>
            <div className="bg-ghost-white border-2 border-dim-gray-400 p-6 rounded-2xl space-y-4 md:col-span-2 lg:col-span-2 hover:-translate-y-0.5 transition-all">
              <div className="w-12 h-12 bg-white text-burnt-orange rounded-xl border-2 border-dim-gray-400 flex items-center justify-center shadow-[3px_3px_0px_0px_rgba(58,56,53,1)] text-xl">⚡</div>
              <h3 className="text-lg font-black text-dim-gray-300">One-Tap Leakage Fix</h3>
              <p className="text-sm text-dim-gray-500 font-medium leading-relaxed">Peel finds unused subscriptions, empty TFSA room, and wrong rewards card categories. One tap: subscriptions cancelled, TFSA scheduled, rewards optimized. Real database writes.</p>
              <div className="bg-white p-3 rounded-xl border-2 border-white-smoke flex justify-between items-center text-xs font-bold text-burnt-orange">
                <span>Total Recoverable Leakage Found:</span><span className="text-sm font-black">$1,027/year</span></div>
            </div>
          </div>
        </div>
      </section>

      {/* PIPELINE */}
      <section id="pipeline" className="max-w-7xl mx-auto px-6">
        <div className="bg-white border-4 border-dim-gray-400 rounded-[32px] p-8 md:p-12 space-y-12 shadow-[8px_8px_0px_0px_rgba(58,56,53,1)]">
          <div className="max-w-xl space-y-2">
            <span className="text-xs font-black text-burnt-orange uppercase tracking-widest">System Internals</span>
            <h2 className="text-3xl font-black text-dim-gray-300 tracking-tight">Three agents, one mission.</h2>
            <p className="text-sm text-dim-gray-500 font-medium">How Peel&apos;s AI agents work together to manage your money.</p>
          </div>
          <div className="grid lg:grid-cols-3 gap-6">
            <div className="bg-floral-white border-2 border-dim-gray-400 p-6 rounded-2xl space-y-3">
              <div className="flex justify-between items-center"><span className="text-xs font-black text-burnt-orange font-mono">STEP 01</span><span className="text-[10px] bg-white border-2 border-dim-gray-400 px-2.5 py-0.5 rounded-full font-black">👁️ watcher</span></div>
              <h4 className="text-base font-black text-dim-gray-300">Parse & Classify</h4>
              <p className="text-xs text-dim-gray-500 font-medium leading-relaxed">Scans receipts with Gemini Vision, categorizes transactions as needs/wants, detects subscriptions, and writes everything to the Supabase database.</p>
            </div>
            <div className="bg-floral-white border-2 border-dim-gray-400 p-6 rounded-2xl space-y-3">
              <div className="flex justify-between items-center"><span className="text-xs font-black text-burnt-orange font-mono">STEP 02</span><span className="text-[10px] bg-white border-2 border-dim-gray-400 px-2.5 py-0.5 rounded-full font-black">🧠 thinker</span></div>
              <h4 className="text-base font-black text-dim-gray-300">Analyze & Advise</h4>
              <p className="text-xs text-dim-gray-500 font-medium leading-relaxed">Calculates needs vs wants, tracks goal progress, finds wasted subscriptions and TFSA room, powers the pre-purchase advisor, and teaches financial concepts.</p>
            </div>
            <div className="bg-floral-white border-2 border-dim-gray-400 p-6 rounded-2xl space-y-3">
              <div className="flex justify-between items-center"><span className="text-xs font-black text-burnt-orange font-mono">STEP 03</span><span className="text-[10px] bg-white border-2 border-dim-gray-400 px-2.5 py-0.5 rounded-full font-black">⚡ doer</span></div>
              <h4 className="text-base font-black text-dim-gray-300">Execute & Confirm</h4>
              <p className="text-xs text-dim-gray-500 font-medium leading-relaxed">Cancels subscriptions, schedules TFSA contributions, switches rewards categories. All with your approval. All written to the real database.</p>
            </div>
          </div>
        </div>
      </section>

      {/* AUTH */}
      {!session && <section id="auth-section" className="max-w-7xl mx-auto px-6">
        <div className="bg-white border-4 border-dim-gray-400 rounded-[32px] p-8 md:p-12 shadow-[8px_8px_0px_0px_rgba(58,56,53,1)] text-center space-y-6">
          <h2 className="text-3xl font-black text-dim-gray-300">Start for free</h2>
          <p className="text-dim-gray-500 font-medium">No credit card. No setup fees. Just sign up and go.</p>
          <AuthForm/>
        </div>
      </section>}
    </main>

    <footer className="bg-dim-gray-300 text-dark-gray py-12 mt-12 border-t-4 border-dim-gray-400">
      <div className="max-w-7xl mx-auto px-6 flex flex-col md:flex-row justify-between items-center gap-6 text-sm font-bold">
        <div className="flex items-center space-x-3">
          <span className="text-2xl font-black text-white tracking-tight">🍊 peel</span>
        </div>
        <p className="text-xs text-dim-gray-500 font-medium">&copy; 2026 Peel Digital Banking Inc. All rights reserved.</p>
      </div>
    </footer>
    </>
  );

  // ─── APP (chat interface in peel style) ────────────────────
  return (
    <div className="min-h-screen bg-white-smoke-1 flex flex-col max-w-lg mx-auto">
      {/* App header */}
      <div className="bg-white border-b-4 border-dim-gray-400 px-4 py-3 flex items-center justify-between sticky top-0 z-50">
        <div className="flex items-center gap-2">
          <span className="text-xl font-black text-burnt-orange">🍊 peel</span>
          <span className="bg-burnt-orange/10 border-2 border-burnt-orange/30 text-burnt-orange text-[10px] font-black px-2 py-0.5 rounded-full">{score}/100</span>
        </div>
        <div className="flex items-center gap-2">
          <button onClick={()=>setShowAgents(!showAgents)} className="bg-ghost-white border-2 border-dim-gray-400 text-xs font-black px-3 py-1.5 rounded-full">⚡ {agentLog.length}</button>
          <button onClick={()=>{setAppOpen(false)}} className="text-xs font-bold text-dim-gray-500">← home</button>
        </div>
      </div>

      {/* Accounts bar */}
      <div className="flex gap-2 p-3 overflow-x-auto bg-white border-b-2 border-white-smoke">
        {accounts.map((a,i)=><div key={i} className="bg-ghost-white border-2 border-dim-gray-400 rounded-xl px-3 py-2 flex-shrink-0 min-w-[120px]">
          <div className="text-[10px] text-dim-gray-500 font-bold">{a.name}</div>
          <div className={"text-sm font-black "+(a.balance<0?"text-red-500":"text-dim-gray-300")}>${Math.abs(a.balance).toLocaleString()}</div>
          <div className="text-[9px] text-dark-gray">{a.institution}</div>
        </div>)}
      </div>

      {/* Actions */}
      <div className="flex gap-2 p-3">
        <button onClick={()=>fileRef.current?.click()} className="flex-1 bg-burnt-orange text-white font-black py-3 rounded-2xl border-b-4 border-black/30 text-sm">📷 Scan Receipt</button>
        <button onClick={getInsights} className="flex-1 bg-dim-gray-400 text-white font-black py-3 rounded-2xl border-b-4 border-black/30 text-sm">✨ Get Insights</button>
      </div>

      {/* Chat */}
      <div className="flex-1 overflow-y-auto px-3 pb-24 space-y-2">
        {receipt&&<div className="bg-white border-2 border-dim-gray-400 rounded-2xl p-3 text-sm">
          <div className="flex justify-between font-black"><span>{receipt.vendor_name}</span><span className="text-burnt-orange">${receipt.total_amount}</span></div>
          <div className="flex gap-1 mt-1">
            <span className="bg-burnt-orange/10 text-burnt-orange text-[10px] font-black px-2 py-0.5 rounded-full">{receipt.category}</span>
            <span className="bg-purple-100 text-purple-600 text-[10px] font-black px-2 py-0.5 rounded-full">{receipt.spend_type}</span>
          </div>
        </div>}

        {msgs.map(m=><div key={m.id}>
          {m.from==="user"&&<div className="flex justify-end"><div className="bg-dim-gray-400 text-white border-2 border-dim-gray-400 p-3 rounded-2xl rounded-tr-none max-w-[85%] text-sm font-semibold lowercase">{m.text}</div></div>}
          {m.from==="system"&&<div className="text-center text-xs text-dark-gray font-bold py-2">{m.text}</div>}
          {m.from==="peel"&&<div className="max-w-[92%]">
            <div className="bg-white text-dim-gray-400 border-2 border-dim-gray-400 p-3 rounded-2xl rounded-tl-none shadow-sm text-sm font-semibold lowercase">
              {m.text}
              {m.insightData?.annual_value>0&&<span className="inline-block ml-2 bg-burnt-orange/10 text-burnt-orange text-[10px] font-black px-2 py-0.5 rounded-full">+${m.insightData.annual_value}/yr</span>}
            </div>
            {m.learnCard&&<LearnCard card={m.learnCard}/>}
          </div>}
        </div>)}

        {msgs.some(m=>m.text?.includes("say go")||m.text?.includes("just say go")||m.type==="action_prompt")&&!done&&
          <button onClick={fixAll} className="w-full bg-burnt-orange text-white font-black py-4 rounded-2xl border-b-4 border-black/30 text-base">⚡ Fix all three — save $1,027/yr</button>}

        {typing&&<div className="flex items-center gap-1 py-2"><span className="w-2 h-2 bg-burnt-orange rounded-full dot"/><span className="w-2 h-2 bg-burnt-orange rounded-full dot"/><span className="w-2 h-2 bg-burnt-orange rounded-full dot"/></div>}
        <div ref={endRef}/>
      </div>

      {/* Input */}
      <div className="fixed bottom-0 left-0 right-0 max-w-lg mx-auto bg-white border-t-2 border-dim-gray-400 px-3 py-3 flex gap-2 z-40">
        <button onClick={()=>fileRef.current?.click()} className="bg-ghost-white border-2 border-dim-gray-400 w-10 h-10 rounded-xl flex items-center justify-center font-bold">📷</button>
        <input value={input} onChange={e=>setInput(e.target.value)} onKeyDown={e=>e.key==="Enter"&&send()}
          placeholder="ask peel anything..." className="flex-1 border-2 border-dim-gray-400 rounded-xl px-4 py-2 text-sm font-semibold outline-none focus:border-burnt-orange bg-ghost-white"/>
        <button onClick={input.trim()?send:getInsights} className="bg-burnt-orange text-white w-10 h-10 rounded-xl flex items-center justify-center font-black border-b-3 border-black/30">{input.trim()?"→":"↑"}</button>
      </div>

      <input ref={fileRef} type="file" accept="image/*" className="hidden" onChange={e=>{const f=e.target.files?.[0];if(f)scanReceipt(f)}}/>

      {/* Agent panel */}
      {showAgents&&<div className="fixed bottom-16 left-0 right-0 max-w-lg mx-auto bg-white border-t-2 border-dim-gray-400 rounded-t-2xl max-h-[40vh] overflow-auto p-4 z-50">
        <div className="flex justify-between mb-3"><span className="text-[10px] font-black text-burnt-orange uppercase tracking-widest">⚡ Agent Activity</span><button onClick={()=>setShowAgents(false)} className="text-dark-gray font-black">✕</button></div>
        {agentLog.map((e,i)=><div key={i} className="flex gap-2 mb-2 text-xs"><span>{e.icon}</span><div><div className="text-[9px] font-black text-dark-gray uppercase">{e.agent}</div><div className="text-dim-gray-500 font-medium">{e.message}</div></div></div>)}
      </div>}
    </div>
  );
}
