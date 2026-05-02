import type { PropsWithChildren } from "react";
import { View, type ViewProps } from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

import { useAppTheme } from "@/theme/useAppTheme";

interface ScreenProps extends PropsWithChildren, ViewProps {
  padded?: boolean;
}

export function Screen({ children, padded = true, style, ...props }: ScreenProps) {
  const { colors } = useAppTheme();

  return (
    <SafeAreaView style={[{ flex: 1, backgroundColor: colors.background }, style]} {...props}>
      <View style={{ flex: 1, paddingHorizontal: padded ? 20 : 0 }}>{children}</View>
    </SafeAreaView>
  );
}
