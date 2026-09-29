// Tokens de marca Rotaviva — espelham 1:1 project/colors_and_type.css do handoff.
// Fonte da verdade é o CSS (tokens.css); este objeto serve consumo em TS/JS (temas, testes, Storybook args).
export const colors = {
  brand: "#0F9D8A",
  brandHover: "#0C8575",
  brandPress: "#0A6E61",
  brandSoft: "#E3F5F2",

  neutral0: "#FFFFFF",
  neutral50: "#F6F8F9",
  neutral100: "#EDF1F3",
  neutral300: "#C5CED4",
  neutral500: "#7A8791",
  neutral700: "#3E4A53",
  neutral900: "#14202A",

  success: "#1E8E3E",
  warning: "#B26A00",
  danger: "#C62828",
  info: "#1565C0",
} as const;

export const surface = {
  surface: colors.neutral0,
  surfaceMuted: colors.neutral50,
  fg: colors.neutral900,
  fgMuted: colors.neutral500,
} as const;

export const typography = {
  fontDisplay: "'Sora', system-ui, sans-serif",
  fontUi: "'Manrope', system-ui, sans-serif",
  fontSize: { 12: "12px", 14: "14px", 16: "16px", 20: "20px", 28: "28px" },
} as const;

export const spacing = {
  1: "4px",
  2: "8px",
  3: "12px",
  4: "16px",
  6: "24px",
  8: "32px",
} as const;

export const radii = {
  sm: "8px",
  md: "12px",
  lg: "20px",
  pill: "999px",
} as const;

export const shadows = {
  1: "0 1px 2px rgba(20, 32, 42, 0.08)",
  2: "0 6px 20px rgba(20, 32, 42, 0.12)",
} as const;

export const motion = {
  easeOut: "cubic-bezier(0.2, 0.8, 0.2, 1)",
  durationFast: "120ms",
  durationBase: "200ms",
} as const;

// Regra do handoff (chats/chat1.md): --brand tem ~3.4:1 de contraste sobre branco — reservado
// para CTA curto e ícone-ação, nunca para texto corrido pequeno (reforçado em project/SKILL.md).
export const brandContrastWarning =
  "brand (#0F9D8A) sobre branco ~3.4:1 — use só em CTA curto/ícone-ação, nunca em texto corrido pequeno.";
