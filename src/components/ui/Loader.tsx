import { ActivityIndicator, View } from "react-native";

import { useAppTheme } from "@/theme/useAppTheme";

export function Loader() {
  const { colors } = useAppTheme();

  return (
    <View style={{ flex: 1, alignItems: "center", justifyContent: "center" }}>
      <ActivityIndicator color={colors.text} />
    </View>
  );
}
