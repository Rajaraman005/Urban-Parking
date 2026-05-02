import { View } from "react-native";

import { useAppTheme } from "@/theme/useAppTheme";

interface SkeletonProps {
  width?: number | `${number}%`;
  height?: number;
  radius?: number;
}

export function Skeleton({ width = "100%", height = 16, radius = 8 }: SkeletonProps) {
  const { colors } = useAppTheme();

  return (
    <View
      style={{
        width,
        height,
        borderRadius: radius,
        backgroundColor: colors.border,
        opacity: 0.65
      }}
    />
  );
}
