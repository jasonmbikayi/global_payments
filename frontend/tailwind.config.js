/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
       "./index.html",
       "./src/**/*.{js,ts,jsx,tsx,vue}",
       "./src/*.jsx"
    // Add other file paths that use Tailwind classes
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}

