import { useColorScheme } from "react-native";

import { darkColors, lightColors } from "@/theme/colors";

export const useAppTheme = () => {
  const scheme = useColorScheme();
  const isDark = scheme === "dark";

  return {
    isDark,
    colors: isDark ? darkColors : lightColors
  };
};
