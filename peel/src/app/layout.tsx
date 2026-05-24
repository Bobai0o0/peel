import type { Metadata } from "next";
import "./globals.css";
export const metadata: Metadata = { title: "Peel — AI Financial Copilot" };
export default function Layout({ children }: { children: React.ReactNode }) {
  return <html lang="en"><body className="bg-white-smoke-1 text-dim-gray-400 font-sans antialiased">{children}</body></html>;
}
