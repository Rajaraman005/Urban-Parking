import { Image, Text, View } from "react-native";

interface OnboardingBrandProps {
  label: string;
}

export function OnboardingBrand({ label }: OnboardingBrandProps) {
  return (
    <View style={{ flexDirection: "row", alignItems: "center", gap: 9 }}>
      <Image
        source={require("../../../assets/logo-mark-sm.png")}
        resizeMode="contain"
        style={{ width: 28, height: 28 }}
      />
      <View style={{ width: 10, height: 1.5, borderRadius: 999, backgroundColor: "#FFFFFF" }} />
      <Text style={{ color: "#FFFFFF", fontSize: 15, fontWeight: "700" }}>{label}</Text>
    </View>
  );
}
