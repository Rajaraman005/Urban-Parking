/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./App.tsx", "./src/**/*.{ts,tsx}"],
  presets: [require("nativewind/preset")],
  theme: {
    extend: {
      colors: {
        ink: "#0B0B0C",
        graphite: "#1D1D1F",
        bone: "#F7F4EF",
        mist: "#ECE8E1",
        taupe: "#A79F95",
        brass: "#B08D57",
        success: "#1E7A54",
        danger: "#B42318"
      },
      fontFamily: {
        sans: ["System"]
      }
    }
  },
  plugins: []
};
