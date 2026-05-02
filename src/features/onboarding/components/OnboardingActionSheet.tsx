import { Pressable, StyleSheet, Text, View } from "react-native";

interface OnboardingActionSheetProps {
  bottomInset: number;
  height: number;
  onLogin: () => void;
  onPrivacyPolicy: () => void;
  onSignup: () => void;
  onTermsOfUse: () => void;
}

export function OnboardingActionSheet({
  bottomInset,
  height,
  onLogin,
  onPrivacyPolicy,
  onSignup,
  onTermsOfUse
}: OnboardingActionSheetProps) {
  return (
    <View style={[styles.sheet, { height, paddingBottom: Math.max(bottomInset + 18, 28) }]}>
      <View style={styles.actions}>
        <ActionButton label="Log in" onPress={onLogin} variant="primary" />
        <OrDivider />
        <ActionButton label="Sign up" onPress={onSignup} variant="secondary" />
      </View>
      <View style={styles.legal}>
        <Text style={styles.legalMuted}>By continuing, you agree to Urban Parking's</Text>
        <View style={styles.legalLinks}>
          <Pressable accessibilityRole="link" hitSlop={6} onPress={onPrivacyPolicy}>
            <Text style={styles.legalStrong}>Privacy Policy</Text>
          </Pressable>
          <Text style={styles.legalMuted}> and </Text>
          <Pressable accessibilityRole="link" hitSlop={6} onPress={onTermsOfUse}>
            <Text style={styles.legalStrong}>Terms of Use</Text>
          </Pressable>
        </View>
      </View>
    </View>
  );
}

function OrDivider() {
  return (
    <View style={styles.orDivider}>
      <View style={styles.orLine} />
      <Text style={styles.orText}>or</Text>
      <View style={styles.orLine} />
    </View>
  );
}

function ActionButton({
  label,
  onPress,
  variant
}: {
  label: string;
  onPress: () => void;
  variant: "primary" | "secondary";
}) {
  const isPrimary = variant === "primary";

  return (
    <Pressable
      accessibilityLabel={label}
      accessibilityRole="button"
      hitSlop={8}
      onPress={onPress}
      style={[styles.button, isPrimary ? styles.primaryButton : styles.secondaryButton]}
    >
      <Text style={[styles.buttonLabel, isPrimary ? styles.primaryLabel : styles.secondaryLabel]}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  sheet: {
    width: "100%",
    backgroundColor: "#FFFFFF",
    borderTopLeftRadius: 28,
    borderTopRightRadius: 28,
    paddingHorizontal: 18,
    paddingTop: 18,
    shadowColor: "#000000",
    shadowOffset: { width: 0, height: -10 },
    shadowOpacity: 0.14,
    shadowRadius: 22,
    elevation: 18
  },
  actions: {
    alignItems: "center",
    gap: 7
  },
  orDivider: {
    width: "100%",
    flexDirection: "row",
    alignItems: "center",
    gap: 10,
    paddingHorizontal: 10
  },
  orLine: {
    flex: 1,
    height: 1,
    backgroundColor: "#E1E1E1"
  },
  orText: {
    color: "#8A8A8A",
    fontSize: 10,
    fontWeight: "800"
  },
  button: {
    width: "100%",
    height: 45,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 24,
    borderWidth: 1
  },
  primaryButton: {
    backgroundColor: "#0B0B0C",
    borderColor: "#0B0B0C",
    shadowColor: "#000000",
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.24,
    shadowRadius: 14,
    elevation: 6
  },
  secondaryButton: {
    backgroundColor: "#FFFFFF",
    borderColor: "#D7D7D7"
  },
  buttonLabel: {
    fontSize: 12,
    fontWeight: "800"
  },
  primaryLabel: {
    color: "#FFFFFF"
  },
  secondaryLabel: {
    color: "#0B0B0C"
  },
  legal: {
    marginTop: 16,
    alignItems: "center"
  },
  legalLinks: {
    flexDirection: "row",
    alignItems: "center",
    justifyContent: "center",
    flexWrap: "wrap"
  },
  legalMuted: {
    color: "#6B6B6B",
    fontSize: 10,
    fontWeight: "600",
    lineHeight: 15,
    textAlign: "center"
  },
  legalStrong: {
    color: "#0B0B0C",
    fontSize: 10,
    fontWeight: "800",
    lineHeight: 15,
    textAlign: "center"
  }
});
