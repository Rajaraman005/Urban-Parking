import { BlurView } from "expo-blur";
import { useEffect, useRef, useState } from "react";
import { Animated, Easing, StyleSheet, Text } from "react-native";

interface GlassDescriptionCardProps {
  text: string;
}

export function GlassDescriptionCard({ text }: GlassDescriptionCardProps) {
  const [visibleText, setVisibleText] = useState(text);
  const opacity = useRef(new Animated.Value(1)).current;
  const translateY = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    opacity.setValue(0);
    translateY.setValue(12);
    setVisibleText(text);

    const animation = Animated.parallel([
      Animated.timing(opacity, {
        toValue: 1,
        duration: 520,
        easing: Easing.out(Easing.cubic),
        useNativeDriver: true
      }),
      Animated.timing(translateY, {
        toValue: 0,
        duration: 560,
        easing: Easing.out(Easing.cubic),
        useNativeDriver: true
      })
    ]);

    animation.start();

    return () => animation.stop();
  }, [opacity, text, translateY]);

  return (
    <Animated.View style={[styles.shadow, { opacity, transform: [{ translateY }] }]}>
      <BlurView intensity={30} tint="dark" style={styles.card}>
        <Text style={styles.text}>{visibleText}</Text>
      </BlurView>
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  shadow: {
    borderRadius: 18,
    overflow: "hidden",
    shadowColor: "#000000",
    shadowOffset: { width: 0, height: 12 },
    shadowOpacity: 0.24,
    shadowRadius: 18,
    elevation: 8
  },
  card: {
    borderRadius: 18,
    borderWidth: 1,
    borderColor: "rgba(255,255,255,0.2)",
    paddingHorizontal: 15,
    paddingVertical: 13,
    backgroundColor: "rgba(255,255,255,0.12)"
  },
  text: {
    color: "#FFFFFF",
    fontSize: 13,
    fontWeight: "700",
    lineHeight: 18
  }
});
