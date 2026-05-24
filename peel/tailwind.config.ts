import type { Config } from "tailwindcss";
const config: Config = {
  content: ["./src/**/*.{js,ts,jsx,tsx}"],
  theme: { extend: { colors: {
    'white-smoke': '#eeeeee', 'white-smoke-1': '#f7f7f7', 'ghost-white': '#fafafa',
    linen: '#f2f0e4', 'floral-white': '#faf9ec', 'dark-gray': '#9e9e9e',
    'burnt-orange': '#f2691d', 'dim-gray-300': '#000000', 'dim-gray-400': '#3a3835',
    'dim-gray-500': '#616161', 'dim-gray-600': '#006fd6',
  }, fontFamily: { sans: ['Inter','Futura','Century Gothic','Helvetica','Arial','sans-serif'] }}},
  plugins: [],
};
export default config;
