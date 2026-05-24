import type { Config } from "tailwindcss";
const config: Config = {
  content: ["./src/**/*.{js,ts,jsx,tsx,mdx}"],
  theme: {
    extend: {
      colors: {
        tangerine: {
          50: "#FFF7ED", 100: "#FFEDD5", 200: "#FED7AA", 300: "#FDBA74",
          400: "#FB923C", 500: "#F58220", 600: "#EA580C", 700: "#C2410C",
          800: "#9A3412", 900: "#7C2D12",
        },
        navy: { 900: "#0F172A", 800: "#1E293B", 700: "#334155" },
      },
    },
  },
  plugins: [],
};
export default config;
