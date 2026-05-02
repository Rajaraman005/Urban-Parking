import { View } from "react-native";

interface PaginationDotsProps {
  activeIndex: number;
  count: number;
}

export function PaginationDots({ activeIndex, count }: PaginationDotsProps) {
  return (
    <View style={{ flexDirection: "row", alignItems: "center", justifyContent: "center", gap: 5 }}>
      {Array.from({ length: count }).map((_, index) => (
        <View
          key={index}
          style={{
            width: index === activeIndex ? 18 : 4,
            height: 3,
            borderRadius: 999,
            backgroundColor: index === activeIndex ? "#FFFFFF" : "rgba(255,255,255,0.46)"
          }}
        />
      ))}
    </View>
  );
}
