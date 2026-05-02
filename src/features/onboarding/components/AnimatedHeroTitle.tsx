import { useEffect, useRef, useState } from "react";
import { Animated, Easing, StyleSheet, View } from "react-native";

interface AnimatedHeroTitleProps {
  align?: "center" | "left";
  title: string;
}

export function AnimatedHeroTitle({ align = "center", title }: AnimatedHeroTitleProps) {
  const [visibleTitle, setVisibleTitle] = useState(title);
  const crispOpacity = useRef(new Animated.Value(1)).current;
  const blurOpacity = useRef(new Animated.Value(0)).current;
  const translateY = useRef(new Animated.Value(0)).current;
  const scale = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    crispOpacity.setValue(0);
    blurOpacity.setValue(0.72);
    translateY.setValue(18);
    scale.setValue(0.97);
    setVisibleTitle(title);

    const animation = Animated.parallel([
      Animated.timing(crispOpacity, {
        toValue: 1,
        duration: 520,
        easing: Easing.out(Easing.cubic),
        useNativeDriver: true
      }),
      Animated.timing(blurOpacity, {
        toValue: 0,
        duration: 520,
        easing: Easing.out(Easing.cubic),
        useNativeDriver: true
      }),
      Animated.timing(translateY, {
        toValue: 0,
        duration: 580,
        easing: Easing.out(Easing.cubic),
        useNativeDriver: true
      }),
      Animated.timing(scale, {
        toValue: 1,
        duration: 580,
        easing: Easing.out(Easing.cubic),
        useNativeDriver: true
      })
    ]);

    animation.start();

    return () => animation.stop();
  }, [blurOpacity, crispOpacity, scale, title, translateY]);

  return (
    <View pointerEvents="none" style={[styles.container, align === "left" ? styles.leftContainer : styles.centerContainer]}>
      <Animated.Text
        style={[
          styles.title,
          align === "left" ? styles.leftTitle : styles.centerTitle,
          styles.blurredTitle,
          {
            opacity: blurOpacity,
            transform: [{ translateY }, { scale }]
          }
        ]}
      >
        {visibleTitle}
      </Animated.Text>
      <Animated.Text
        style={[
          styles.title,
          align === "left" ? styles.leftTitle : styles.centerTitle,
          {
            opacity: crispOpacity,
            transform: [{ translateY }, { scale }]
          }
        ]}
      >
        {visibleTitle}
      </Animated.Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    justifyContent: "center"
  },
  centerContainer: {
    alignItems: "center"
  },
  leftContainer: {
    alignItems: "flex-start"
  },
  title: {
    color: "#FFFFFF",
    fontSize: 30,
    fontWeight: "900",
    lineHeight: 36
  },
  centerTitle: {
    textAlign: "center"
  },
  leftTitle: {
    textAlign: "left"
  },
  blurredTitle: {
    position: "absolute",
    textShadowColor: "rgba(255,255,255,0.9)",
    textShadowOffset: { width: 0, height: 0 },
    textShadowRadius: 12
  }
});
