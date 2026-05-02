import { ActivityIndicator, Pressable, StyleSheet, Text, View } from "react-native";

import { GoogleLogo } from "@/features/auth/components/GoogleLogo";

interface PrimaryAuthButtonProps {
  disabled?: boolean;
  label: string;
  loading?: boolean;
  onPress: () => void;
}

export function PrimaryAuthButton({ disabled, label, loading, onPress }: PrimaryAuthButtonProps) {
  const isDisabled = Boolean(disabled || loading);

  return (
    <Pressable
      accessibilityRole="button"
      disabled={isDisabled}
      onPress={onPress}
      style={[styles.primaryButton, isDisabled ? styles.disabledButton : null]}
    >
      {loading ? <ActivityIndicator color="#FFFFFF" /> : <Text style={styles.primaryLabel}>{label}</Text>}
    </Pressable>
  );
}

export function GoogleAuthButton({
  disabled,
  loading,
  onPress
}: {
  disabled?: boolean;
  loading?: boolean;
  onPress: () => void;
}) {
  const isDisabled = Boolean(disabled || loading);

  return (
    <Pressable
      accessibilityRole="button"
      disabled={isDisabled}
      onPress={onPress}
      style={[styles.socialButton, isDisabled ? styles.disabledButton : null]}
    >
      {loading ? (
        <ActivityIndicator color="#0B0B0C" />
      ) : (
        <View style={styles.googleMark}>
          <GoogleLogo size={20} />
        </View>
      )}
      <Text style={styles.socialLabel}>Continue with Google</Text>
    </Pressable>
  );
}

export function AuthDivider() {
  return (
    <View style={styles.divider}>
      <View style={styles.line} />
      <Text style={styles.dividerText}>or</Text>
      <View style={styles.line} />
    </View>
  );
}

const styles = StyleSheet.create({
  primaryButton: {
    width: "100%",
    height: 56,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 28,
    backgroundColor: "#0B0B0C",
    shadowColor: "#000000",
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.24,
    shadowRadius: 16,
    elevation: 7
  },
  disabledButton: {
    opacity: 0.58
  },
  primaryLabel: {
    color: "#FFFFFF",
    fontSize: 14,
    fontWeight: "900"
  },
  socialButton: {
    width: "100%",
    height: 50,
    alignItems: "center",
    justifyContent: "center",
    flexDirection: "row",
    gap: 10,
    borderRadius: 25,
    borderWidth: 1,
    borderColor: "#DCDCDC",
    backgroundColor: "#FFFFFF"
  },
  googleMark: {
    width: 20,
    height: 20,
    alignItems: "center",
    justifyContent: "center"
  },
  socialLabel: {
    color: "#0B0B0C",
    fontSize: 13,
    fontWeight: "900"
  },
  divider: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    paddingHorizontal: 8
  },
  line: {
    flex: 1,
    height: 1,
    backgroundColor: "#E3E3E3"
  },
  dividerText: {
    color: "#8A8A8A",
    fontSize: 11,
    fontWeight: "800"
  }
});
