import { Text, TextInput, View, type TextInputProps } from "react-native";

import { useAppTheme } from "@/theme/useAppTheme";

interface InputProps extends TextInputProps {
  label: string;
  error?: string;
}

export function Input({ label, error, style, ...props }: InputProps) {
  const { colors } = useAppTheme();

  return (
    <View style={{ gap: 8 }}>
      <Text style={{ color: colors.text, fontSize: 13, fontWeight: "700" }}>{label}</Text>
      <TextInput
        placeholderTextColor={colors.muted}
        style={[
          {
            minHeight: 54,
            borderRadius: 8,
            borderWidth: 1,
            borderColor: error ? colors.danger : colors.border,
            backgroundColor: colors.surface,
            color: colors.text,
            paddingHorizontal: 16,
            fontSize: 16
          },
          style
        ]}
        {...props}
      />
      {error ? <Text style={{ color: colors.danger, fontSize: 13 }}>{error}</Text> : null}
    </View>
  );
}
