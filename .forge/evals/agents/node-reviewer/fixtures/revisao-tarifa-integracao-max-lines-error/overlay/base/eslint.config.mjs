import tseslint from "typescript-eslint";
import forgeQuality from "./.forge/capabilities/backend-node-postgres/assets/eslint-rules/index.cjs";

export default [
  ...tseslint.configs.recommended,
  {
    files: ["src/**/*.{ts,tsx,js,jsx}"],
    plugins: { "forge-quality": forgeQuality },
    rules: {
      "forge-quality/no-direct-console": "error",
      // Arquivo grande demais não passa: decidido na retro da sprint 14.
      "forge-quality/max-lines": ["error", { max: 300 }],
      "forge-quality/no-direct-data-access": ["error", { modules: ["pg"], layers: ["src/http"] }],
    },
  },
];
