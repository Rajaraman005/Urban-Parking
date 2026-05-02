export const lightColors = {
  background: "#FFFFFF",
  surface: "#FFFFFF",
  elevated: "#FFFFFF",
  text: "#0B0B0C",
  muted: "#6B6B6B",
  border: "#E3E3E3",
  primary: "#0B0B0C",
  primaryText: "#FFFFFF",
  accent: "#0B0B0C",
  success: "#1E7A54",
  danger: "#B42318"
} as const;

export const darkColors = {
  background: "#0B0B0C",
  surface: "#151517",
  elevated: "#1D1D1F",
  text: "#FFFFFF",
  muted: "#B9B1A7",
  border: "#2C2B2A",
  primary: "#FFFFFF",
  primaryText: "#0B0B0C",
  accent: "#C9A76A",
  success: "#6BD0A0",
  danger: "#FF8A80"
} as const;

export type AppColors = typeof lightColors;
