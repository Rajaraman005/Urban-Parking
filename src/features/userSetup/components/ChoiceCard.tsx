import { Ionicons } from "@expo/vector-icons";

import { LinearGradient } from "expo-linear-gradient";
import type { ImageSourcePropType } from "react-native";
import {
  ImageBackground,
  Pressable,
  StyleSheet,
  Text,
  View,
} from "react-native";

interface ChoiceCardProps {
  description: string;
  icon: keyof typeof Ionicons.glyphMap;
  imageSource?: ImageSourcePropType;
  selected?: boolean;
  title: string;
  onPress: () => void;
}

export function ChoiceCard({
  description,
  icon,
  imageSource,
  selected,
  title,
  onPress,
}: ChoiceCardProps) {
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ selected }}
      style={[
        styles.card,
        imageSource ? styles.mediaCard : null,
        selected ? styles.selected : null,
      ]}
      onPress={onPress}
    >
      {imageSource ? (
        <ImageBackground
          imageStyle={styles.mediaImage}
          resizeMode="cover"
          source={imageSource}
          style={styles.mediaBackground}
        >
          <LinearGradient
            colors={[
              "rgba(0,0,0,0.15)",
              "rgba(0,0,0,0.4)",
              "rgba(0,0,0,0.7)",
            ]}
            locations={[0, 0.45, 1]}
            style={styles.mediaGradient}
          />
          <View style={styles.mediaContentOverlay}>
            <View style={styles.mediaCopy}>
              <Text style={styles.mediaTitle}>{title}</Text>
              <Text style={styles.mediaDescription}>{description}</Text>
            </View>
            <Ionicons
              color={selected ? "#FFFFFF" : "rgba(255,255,255,0.5)"}
              name={selected ? "checkmark-circle" : "ellipse-outline"}
              size={24}
            />
          </View>
        </ImageBackground>
      ) : (
        <>
          <View
            style={[styles.iconWrap, selected ? styles.selectedIconWrap : null]}
          >
            <Ionicons color="#0A0A0B" name={icon} size={24} />
          </View>
          <View style={styles.copy}>
            <Text style={styles.title}>{title}</Text>
            <Text style={styles.description}>{description}</Text>
          </View>
          <Ionicons
            color={selected ? "#0A0A0B" : "#A3A3A3"}
            name={selected ? "checkmark-circle" : "ellipse-outline"}
            size={24}
          />
        </>
      )}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: {
    minHeight: 118,
    padding: 18,
    borderRadius: 22,
    borderWidth: 1,
    borderColor: "rgba(10,10,10,0.10)",
    backgroundColor: "#FFFFFF",
    flexDirection: "row",
    alignItems: "center",
    gap: 14,
  },
  mediaCard: {
    height: 156,
    width: "100%",
    padding: 0,
    overflow: "hidden",
    borderColor: "rgba(10,10,10,0.08)",
    alignItems: "stretch",
    flexDirection: "column",
    gap: 0,
  },
  selected: {
    borderColor: "#0A0A0B",
    borderWidth: 2,
    backgroundColor: "#FFFFFF",
  },
  mediaBackground: {
    flex: 1,
    width: "100%",
    justifyContent: "center",
  },
  mediaImage: {
    borderRadius: 22,
  },
  mediaGradient: {
    ...StyleSheet.absoluteFillObject,
  },
  mediaContentOverlay: {
    padding: 24,
    flexDirection: "row",
    alignItems: "center",
    gap: 16,
    flex: 1,
  },
  mediaCopy: {
    flex: 1,
    gap: 6,
  },
  mediaTitle: {
    color: "#FFFFFF",
    fontSize: 22,
    fontWeight: "900",
  },
  mediaDescription: {
    color: "rgba(255,255,255,0.85)",
    fontSize: 14,
    fontWeight: "600",
    lineHeight: 20,
  },
  iconWrap: {
    width: 46,
    height: 46,
    borderRadius: 16,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#F4F4F4",
  },
  selectedIconWrap: {
    backgroundColor: "#EFEFEF",
  },
  copy: {
    flex: 1,
    gap: 6,
  },
  title: {
    color: "#0A0A0B",
    fontSize: 18,
    fontWeight: "900",
  },
  description: {
    color: "#666666",
    fontSize: 13,
    fontWeight: "700",
    lineHeight: 18,
  },
});
