import type { PropsWithChildren } from "react";
import { StyleSheet, Text, View } from "react-native";

import { Screen } from "@/components/ui/Screen";
import { useAppTheme } from "@/theme/useAppTheme";

interface AuthFormLayoutProps extends PropsWithChildren {
  description: string;
  error?: string | null;
  title: string;
}

export function AuthFormLayout({ children, description, error, title }: AuthFormLayoutProps) {
  const { colors } = useAppTheme();

  return (
    <Screen>
      <View style={styles.container}>
        <View style={styles.copy}>
          <Text style={[styles.title, { color: colors.text }]}>{title}</Text>
          <Text style={[styles.description, { color: colors.muted }]}>{description}</Text>
        </View>
        {error ? (
          <View style={[styles.errorBanner, { borderColor: colors.danger }]}>
            <Text style={[styles.errorText, { color: colors.danger }]}>{error}</Text>
          </View>
        ) : null}
        <View style={styles.form}>{children}</View>
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: "center",
    gap: 22
  },
  copy: {
    gap: 8
  },
  title: {
    fontSize: 32,
    fontWeight: "900",
    letterSpacing: 0,
    lineHeight: 38
  },
  description: {
    fontSize: 15,
    fontWeight: "600",
    lineHeight: 22
  },
  errorBanner: {
    borderWidth: 1,
    borderRadius: 8,
    paddingHorizontal: 14,
    paddingVertical: 12
  },
  errorText: {
    fontSize: 13,
    fontWeight: "800",
    lineHeight: 18
  },
  form: {
    gap: 16
  }
});
