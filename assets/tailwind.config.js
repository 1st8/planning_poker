module.exports = {
  mode: "jit",
  purge: [
    "../lib/**/*.heex",
    "../lib/planning_poker_web/components/*.ex",
    "./js/**/*.{js,jsx,ts,tsx,vue}",
  ],
  darkMode: false, // or 'media' or 'class'
  theme: {
    extend: {},
  },
  variants: {
    extend: {},
  },
  plugins: [
    require("@tailwindcss/typography"),
    require("@tailwindcss/forms"),
    require("daisyui"),
  ],
};
