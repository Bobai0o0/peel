import type { Metadata } from "next";
export const metadata: Metadata = { title: "Peel" };
export default function Layout({ children }: { children: React.ReactNode }) {
  return <html lang="en"><head><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1" /></head><body style={{background:"#0a0a0f",color:"#fff",fontFamily:"-apple-system,sans-serif",margin:0}}>{children}</body></html>;
}
