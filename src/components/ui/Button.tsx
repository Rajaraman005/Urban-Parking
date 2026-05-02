import { ActivityIndicator, Pressable, Text, type PressableProps, type StyleProp, type ViewStyle } from "react-native";

import { useAppTheme } from "@/theme/useAppTheme";

interface ButtonProps extends Omit<PressableProps, "style"> {
  label: string;
  variant?: "primary" | "secondary" | "ghost";
  loading?: boolean;
  style?: StyleProp<ViewStyle>;
}

export function Button({ label, variant = "primary", loading, disabled, style, ...props }: ButtonProps) {
  const { colors } = useAppTheme();
  const isDisabled = disabled || loading;

  const backgroundColor =
    variant === "primary" ? colors.primary : variant === "secondary" ? colors.elevated : "transparent";
  const borderColor = variant === "ghost" ? "transparent" : colors.border;
  const textColor = variant === "primary" ? colors.primaryText : colors.text;

  return (
    <Pressable
      accessibilityRole="button"
      disabled={isDisabled}
      style={[
        {
          width: "100%",
          height: 56,
          alignItems: "center",
          justifyContent: "center",
          borderRadius: 8,
          borderWidth: 1,
          borderColor,
          backgroundColor,
          opacity: isDisabled ? 0.55 : 1
        },
        style
      ]}
      {...props}
    >
      {loading ? (
        <ActivityIndicator color={textColor} />
      ) : (
        <Text style={{ color: textColor, fontSize: 16, fontWeight: "700" }}>{label}</Text>
      )}
    </Pressable>
  );
}
