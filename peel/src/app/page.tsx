"use client";
import { useState, useRef, useEffect, useCallback } from "react";
import { createClient } from "@supabase/supabase-js";

const sb = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!);

export default function Home() {
  const [session, setSession] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [seeded, setSeeded] = useState(false);
  const [accounts, setAccounts] = useState<any[]>([]);
  const [msgs, setMsgs] = useState<{id:string;from:string;text:string;learnCard?:any;insightData?:any}[]>([]);
  const [typing, setTyping] = useState(false);
  const [input, setInput] = useState("");
  const [done, setDone] = useState(false);
  const [agentLog, setAgentLog] = useState<{agent:string;icon:string;message:string}[]>([]);
  const [showAgents, setShowAgents] = useState(false);
  const [receipt, setReceipt] = useState<any>(null);
  const endRef = useRef<HTMLDivElement>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    sb.auth.getSession().then(({data:{session:s}}) => { setSession(s); setLoading(false) });
    const {data:{subscription}} = sb.auth.onAuthStateChange((_,s) => setSession(s));
    return () => subscription.unsubscribe();
  }, []);

  useEffect(() => {
    if (!session || !seeded) return;
    const uid = session.user.id;
    sb.from("accounts").select("*").eq("user_id", uid).then(({data}) => { if(data) setAccounts(data) });
    const ch = sb.channel("a").on("postgres_changes",{event:"UPDATE",schema:"public",table:"accounts"},p=>{
      setAccounts(prev=>prev.map(a=>a.name===p.new.name?{...a,balance:p.new.balance}:a));
    }).subscribe();
    return ()=>{sb.removeChannel(ch)};
  }, [session, seeded]);

  useEffect(() => { endRef.current?.scrollIntoView({behavior:"smooth"}) }, [msgs, typing]);

  const uid = session?.user?.id;
  const name = session?.user?.email?.split("@")[0] || "there";

  const addPeel = useCallback(async (text:string, extra?:any) => {
    setTyping(true);
    await new Promise(r=>setTimeout(r,500+Math.random()*600));
    setTyping(false);
    setMsgs(p=>[...p,{id:crypto.randomUUID(),from:"peel",text,...extra}]);
  },[]);

  const seed = async () => {
    const res = await fetch("/api/seed-demo",{method:"POST",headers:{"Authorization":"Bearer "+session.access_token}});
    const d = await res.json();
    if (d.ok) setSeeded(true);
  };

  const scanReceipt = async (file:File) => {
    if(!uid) return;
    setMsgs(p=>[...p,{id:crypto.randomUUID(),from:"user",text:"📷 [receipt]"}]);
    setTyping(true);
    const reader = new FileReader();
    reader.onload = async () => {
      const res = await fetch("/api/receipt",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({image:reader.result,userId:uid})});
      const d = await res.json();
      setTyping(false);
      if(d.receipt) {
        setReceipt(d.receipt);
        setAgentLog(p=>[...p,...(d.activityLog||[])]);
        for(const m of d.analysis?.messages||[]) await addPeel(m.text);
        if(!d.analysis?.messages?.length) await addPeel(`got it — $${d.receipt.total_amount} at ${d.receipt.vendor_name}, ${d.receipt.category} (${d.receipt.spend_type})`);
      }
    };
    reader.readAsDataURL(file);
  };

  const getInsights = async () => {
    if(!uid) return;
    setMsgs(p=>[...p,{id:crypto.randomUUID(),from:"system",text:"analyzing..."}]);
    setTyping(true);
    const res = await fetch("/api/insights",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({userId:uid})});
    const d = await res.json();
    setTyping(false);
    setAgentLog(p=>[...p,...(d.activityLog||[])]);
    for(const m of d.data?.messages||[]) await addPeel(m.text,{learnCard:m.learn_card,insightData:m.insight_data});
  };

  const fixAll = async () => {
    if(!uid) return;
    setMsgs(p=>[...p,{id:crypto.randomUUID(),from:"user",text:"go 🚀"}]);
    setTyping(true);
    const res = await fetch("/api/execute",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({userId:uid})});
    const d = await res.json();
    setTyping(false);
    for(const m of d.execution?.execution_messages||[]) await addPeel(m.text);
    if(d.execution?.completion_message) await addPeel(d.execution.completion_message);
    if(d.updatedAccounts) setAccounts(d.updatedAccounts);
    setDone(true);
  };

  const checkPurchase = async (text:string) => {
    if(!uid) return;
    setMsgs(p=>[...p,{id:crypto.randomUUID(),from:"user",text}]);
    setTyping(true);
    const res = await fetch("/api/purchase-check",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({message:text,userId:uid})});
    const d = await res.json();
    setTyping(false);
    for(const m of d.data?.messages||[]) await addPeel(m.text);
  };

  const send = () => {
    if(!input.trim()) return;
    const t = input.trim(); setInput("");
    const l = t.toLowerCase();
    if(l.includes("buy")||l.includes("should i")||l.includes("afford")||l.includes("worth")||l.includes("splurge")) checkPurchase(t);
    else if(l.includes("insight")||l.includes("analyze")) getInsights();
    else checkPurchase(t);
  };

  // ─── STYLES ──────────────────────────────────────────────
  const S = {
    shell: {height:"100dvh",display:"flex",flexDirection:"column" as const,maxWidth:430,margin:"0 auto",overflow:"hidden"},
    header: {padding:"44px 16px 12px",display:"flex",justifyContent:"space-between",alignItems:"center",borderBottom:"1px solid rgba(255,255,255,0.06)"},
    logo: {display:"flex",alignItems:"center",gap:8},
    icon: {width:32,height:32,borderRadius:"50%",background:"linear-gradient(135deg,#FB923C,#EA580C)",display:"flex",alignItems:"center",justifyContent:"center",fontSize:14},
    brand: {fontWeight:800,fontSize:14,background:"linear-gradient(135deg,#F58220,#FF6B35)",WebkitBackgroundClip:"text",WebkitTextFillColor:"transparent"},
    scroll: {flex:1,overflowY:"auto" as const,padding:"0 0 100px"},
    card: {margin:"8px 16px",padding:14,background:"rgba(255,255,255,0.04)",borderRadius:16,border:"1px solid rgba(255,255,255,0.06)"},
    bubblePeel: {margin:"4px 16px",maxWidth:"85%",padding:"10px 14px",background:"rgba(255,255,255,0.07)",borderRadius:"18px 18px 18px 4px",fontSize:15,lineHeight:1.5,color:"#e5e5e5"},
    bubbleUser: {margin:"4px 16px",maxWidth:"80%",marginLeft:"auto",padding:"10px 14px",background:"#F58220",borderRadius:"18px 18px 4px 18px",fontSize:15,color:"#fff"},
    bubbleSys: {margin:"8px auto",fontSize:12,color:"#666",textAlign:"center" as const},
    learn: {margin:"2px 16px 2px 44px",padding:"8px 12px",background:"rgba(59,130,246,0.1)",border:"1px solid rgba(59,130,246,0.2)",borderRadius:12,fontSize:12,color:"#60a5fa",cursor:"pointer"},
    val: {display:"inline-block",marginTop:6,padding:"2px 8px",background:"rgba(245,130,32,0.15)",borderRadius:8,fontSize:12,fontWeight:700,color:"#FB923C"},
    input: {position:"fixed" as const,bottom:0,left:0,right:0,maxWidth:430,margin:"0 auto",padding:"12px",display:"flex",gap:8,background:"rgba(10,10,15,0.9)",borderTop:"1px solid rgba(255,255,255,0.06)",backdropFilter:"blur(20px)"},
    inputField: {flex:1,background:"rgba(255,255,255,0.04)",border:"1px solid rgba(255,255,255,0.06)",borderRadius:24,padding:"10px 16px",color:"#fff",fontSize:14,outline:"none"},
    btn: {padding:"10px 16px",background:"linear-gradient(135deg,#F58220,#EA580C)",border:"none",borderRadius:24,color:"#fff",fontWeight:600,fontSize:13,cursor:"pointer"},
    btnSm: {padding:"6px 12px",background:"rgba(255,255,255,0.04)",border:"1px solid rgba(255,255,255,0.06)",borderRadius:12,color:"#aaa",fontSize:12,cursor:"pointer"},
    fixBtn: {margin:"8px 16px",padding:"14px",background:"linear-gradient(135deg,#F58220,#EA580C)",border:"none",borderRadius:16,color:"#fff",fontWeight:700,fontSize:15,cursor:"pointer",width:"calc(100% - 32px)",textAlign:"center" as const},
    dots: {display:"flex",gap:4,padding:"12px 16px"},
    dot: {width:8,height:8,borderRadius:"50%",background:"#F58220",opacity:0.6},
    agentPanel: {position:"fixed" as const,bottom:0,left:0,right:0,maxWidth:430,margin:"0 auto",maxHeight:"40vh",background:"rgba(15,23,42,0.95)",borderTop:"1px solid rgba(255,255,255,0.1)",borderRadius:"16px 16px 0 0",overflow:"auto",padding:12,zIndex:50},
    agentEntry: {display:"flex",gap:8,marginBottom:8,fontSize:12,color:"#999"},
  };

  if(loading) return <div style={{...S.shell,justifyContent:"center",alignItems:"center"}}><p style={{color:"#666"}}>Loading...</p></div>;

  if(!session) return (
    <div style={{...S.shell,justifyContent:"center",alignItems:"center",padding:24}}>
      <div style={{...S.icon,width:64,height:64,fontSize:28,marginBottom:24}}>🍊</div>
      <h1 style={{...S.brand,fontSize:28,marginBottom:4}}>Peel</h1>
      <p style={{color:"#666",fontSize:14,marginBottom:32}}>AI financial copilot</p>
      <AuthForm/>
    </div>
  );

  if(!seeded) return (
    <div style={{...S.shell,justifyContent:"center",alignItems:"center",padding:24}}>
      <div style={{...S.icon,width:64,height:64,fontSize:28,marginBottom:24}}>🍊</div>
      <h1 style={{...S.brand,fontSize:22,marginBottom:8}}>Welcome to Peel</h1>
      <p style={{color:"#888",fontSize:14,marginBottom:24,textAlign:"center"}}>load demo data to get started</p>
      <button onClick={seed} style={S.btn}>Load demo data →</button>
      <button onClick={()=>sb.auth.signOut()} style={{...S.btnSm,marginTop:16}}>sign out</button>
    </div>
  );

  const total = accounts.reduce((s,a)=>s+a.balance,0);

  return (
    <div style={S.shell}>
      <div style={S.header}>
        <div style={S.logo}><div style={S.icon}>🍊</div><span style={S.brand}>Peel</span></div>
        <div style={{display:"flex",gap:8}}>
          <button onClick={()=>setShowAgents(!showAgents)} style={S.btnSm}>⚡ {agentLog.length}</button>
          <button onClick={()=>sb.auth.signOut()} style={S.btnSm}>logout</button>
        </div>
      </div>

      <div style={S.scroll}>
        {/* Accounts */}
        <div style={S.card}>
          <div style={{fontSize:11,color:"#888",textTransform:"uppercase",letterSpacing:1}}>Net Worth</div>
          <div style={{fontSize:28,fontWeight:900}}>${total.toLocaleString()}</div>
        </div>
        <div style={{display:"flex",gap:8,padding:"0 16px",overflowX:"auto"}}>
          {accounts.map((a,i)=><div key={i} style={{...S.card,margin:0,minWidth:130,flex:"0 0 auto"}}>
            <div style={{fontSize:11,color:"#888"}}>{a.name}</div>
            <div style={{fontSize:15,fontWeight:700,color:a.balance<0?"#f87171":"#fff"}}>${Math.abs(a.balance).toLocaleString()}</div>
            <div style={{fontSize:10,color:"#555"}}>{a.institution}</div>
          </div>)}
        </div>

        {/* Actions */}
        <div style={{display:"flex",gap:8,padding:"12px 16px"}}>
          <button onClick={()=>fileRef.current?.click()} style={{...S.btn,flex:1,fontSize:13}}>📷 Scan Receipt</button>
          <button onClick={getInsights} style={{...S.btn,flex:1,fontSize:13}}>✨ Get Insights</button>
        </div>

        {/* Receipt */}
        {receipt && <div style={S.card}>
          <div style={{display:"flex",justifyContent:"space-between"}}><b>{receipt.vendor_name}</b><span style={{color:"#FB923C",fontWeight:700}}>${receipt.total_amount}</span></div>
          <div style={{display:"flex",gap:4,marginTop:4}}>
            <span style={{padding:"2px 6px",background:"rgba(245,130,32,0.15)",borderRadius:6,fontSize:11,color:"#FB923C"}}>{receipt.category}</span>
            <span style={{padding:"2px 6px",background:"rgba(168,85,247,0.15)",borderRadius:6,fontSize:11,color:"#a855f7"}}>{receipt.spend_type}</span>
          </div>
        </div>}

        {/* Chat */}
        {msgs.map(m=>(
          <div key={m.id}>
            {m.from==="user"&&<div style={S.bubbleUser}>{m.text}</div>}
            {m.from==="system"&&<div style={S.bubbleSys}>{m.text}</div>}
            {m.from==="peel"&&<div style={{display:"flex",gap:8,padding:"4px 16px"}}>
              <div style={{...S.icon,width:28,height:28,fontSize:12,flexShrink:0}}>🍊</div>
              <div>
                <div style={S.bubblePeel}>{m.text}
                  {m.insightData?.annual_value>0&&<div style={S.val}>+${m.insightData.annual_value}/yr</div>}
                </div>
                {m.learnCard&&<LearnCard card={m.learnCard}/>}
              </div>
            </div>}
          </div>
        ))}

        {msgs.some(m=>m.text?.includes("say go"))&&!done&&<button onClick={fixAll} style={S.fixBtn}>⚡ Fix all three — save $1,027/yr</button>}
        {typing&&<div style={S.dots}><div style={{...S.dot,animation:"pulse 1.4s infinite"}}/><div style={{...S.dot,animation:"pulse 1.4s infinite .2s"}}/><div style={{...S.dot,animation:"pulse 1.4s infinite .4s"}}/></div>}
        <div ref={endRef}/>
      </div>

      <div style={S.input}>
        <button onClick={()=>fileRef.current?.click()} style={{...S.btnSm,padding:"10px 12px"}}>📷</button>
        <input value={input} onChange={e=>setInput(e.target.value)} onKeyDown={e=>e.key==="Enter"&&send()} placeholder="ask peel anything..." style={S.inputField}/>
        <button onClick={input.trim()?send:getInsights} style={{...S.btn,borderRadius:"50%",width:40,height:40,padding:0,display:"flex",alignItems:"center",justifyContent:"center"}}>{input.trim()?"→":"↑"}</button>
      </div>

      <input ref={fileRef} type="file" accept="image/*" className="hidden" style={{display:"none"}} onChange={e=>{const f=e.target.files?.[0];if(f)scanReceipt(f)}}/>

      {showAgents&&<div style={S.agentPanel}>
        <div style={{display:"flex",justifyContent:"space-between",marginBottom:8}}><b style={{fontSize:11,color:"#888",textTransform:"uppercase",letterSpacing:1}}>⚡ Agents</b><button onClick={()=>setShowAgents(false)} style={{background:"none",border:"none",color:"#666",cursor:"pointer"}}>✕</button></div>
        {agentLog.map((e,i)=><div key={i} style={S.agentEntry}><span>{e.icon}</span><div><div style={{fontSize:10,fontWeight:700,color:"#555",textTransform:"uppercase"}}>{e.agent}</div><div>{e.message}</div></div></div>)}
      </div>}

      <style>{`@keyframes pulse{0%,80%,100%{opacity:.3}40%{opacity:1}}`}</style>
    </div>
  );
}

function LearnCard({card}:{card:any}) {
  const [open,setOpen]=useState(false);
  return <div>
    <div onClick={()=>setOpen(!open)} style={{margin:"2px 0",padding:"6px 10px",background:"rgba(59,130,246,0.1)",border:"1px solid rgba(59,130,246,0.2)",borderRadius:10,fontSize:12,color:"#60a5fa",cursor:"pointer"}}>💡 {card.title} {open?"▲":"▼"}</div>
    {open&&<div style={{padding:"8px 10px",background:"rgba(255,255,255,0.03)",borderRadius:10,marginTop:2,fontSize:13,color:"#ccc",lineHeight:1.5}}>
      <p>{card.explanation}</p>
      <p style={{marginTop:6,padding:"6px 8px",background:"rgba(245,130,32,0.1)",borderRadius:8,fontSize:12,color:"#FB923C"}}>🎯 {card.pro_tip}</p>
    </div>}
  </div>;
}

function AuthForm() {
  const [email,setEmail]=useState("");
  const [pass,setPass]=useState("");
  const [mode,setMode]=useState<"login"|"signup">("signup");
  const [err,setErr]=useState("");
  const go = async () => {
    setErr("");
    const {error} = mode==="signup"
      ? await sb.auth.signUp({email,password:pass})
      : await sb.auth.signInWithPassword({email,password:pass});
    if(error) setErr(error.message);
  };
  return <div style={{width:"100%",maxWidth:320}}>
    <input value={email} onChange={e=>setEmail(e.target.value)} placeholder="email" style={{width:"100%",padding:"12px 16px",background:"rgba(255,255,255,0.05)",border:"1px solid rgba(255,255,255,0.1)",borderRadius:12,color:"#fff",fontSize:14,outline:"none",marginBottom:8,boxSizing:"border-box"}}/>
    <input value={pass} onChange={e=>setPass(e.target.value)} placeholder="password" type="password" style={{width:"100%",padding:"12px 16px",background:"rgba(255,255,255,0.05)",border:"1px solid rgba(255,255,255,0.1)",borderRadius:12,color:"#fff",fontSize:14,outline:"none",marginBottom:12,boxSizing:"border-box"}}/>
    {err&&<p style={{color:"#f87171",fontSize:12,marginBottom:8}}>{err}</p>}
    <button onClick={go} style={{width:"100%",padding:"12px",background:"linear-gradient(135deg,#F58220,#EA580C)",border:"none",borderRadius:12,color:"#fff",fontWeight:600,fontSize:15,cursor:"pointer"}}>{mode==="signup"?"Sign Up":"Log In"}</button>
    <button onClick={()=>setMode(mode==="signup"?"login":"signup")} style={{width:"100%",marginTop:8,background:"none",border:"none",color:"#888",fontSize:13,cursor:"pointer"}}>{mode==="signup"?"already have an account? log in":"need an account? sign up"}</button>
  </div>;
}
