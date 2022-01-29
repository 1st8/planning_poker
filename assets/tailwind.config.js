module.exports = {
  content: [
    "../lib/**/*.heex",
    "../lib/planning_poker_web/components/*.ex",
    "./js/**/*.{js,jsx,ts,tsx,vue,svelte}",
  ],
  plugins: [
    require("@tailwindcss/typography"),
    require("@tailwindcss/forms"),
    require("daisyui"),
  ],
};
