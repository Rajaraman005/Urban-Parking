import { StyleSheet, View } from "react-native";

interface PasswordStrengthMeterProps {
  password: string;
}

const rules = [
  (value: string) => value.length >= 8,
  (value: string) => /[A-Z]/.test(value) && /[a-z]/.test(value),
  (value: string) => /[0-9]/.test(value),
  (value: string) => /[^A-Za-z0-9]/.test(value)
] as const;

const colorForScore = (score: number) => {
  if (score >= 4) {
    return "#16A34A";
  }

  if (score >= 3) {
    return "#D97706";
  }

  if (score >= 1) {
    return "#DC2626";
  }

  return "#E7E7E7";
};

export function PasswordStrengthMeter({ password }: PasswordStrengthMeterProps) {
  const score = rules.filter((rule) => rule(password)).length;
  const activeColor = colorForScore(score);

  return (
    <View style={styles.container}>
      {rules.map((rule, index) => (
        <View
          key={String(index)}
          style={[
            styles.segment,
            {
              backgroundColor: index < score ? activeColor : "#E7E7E7"
            }
          ]}
        />
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: "row",
    gap: 5,
    marginTop: -8,
    paddingHorizontal: 2
  },
  segment: {
    flex: 1,
    height: 4,
    borderRadius: 999
  }
});
