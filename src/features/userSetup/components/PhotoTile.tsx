import { Ionicons } from "@expo/vector-icons";
import { Image, Pressable, StyleSheet, Text, View } from "react-native";

interface PhotoTileProps {
  uri?: string;
  label?: string;
  uploading?: boolean;
  onPress?: () => void;
  onDelete?: () => void;
}

export function PhotoTile({ label = "Add photo", onDelete, onPress, uploading, uri }: PhotoTileProps) {
  return (
    <Pressable accessibilityRole="button" style={styles.tile} onPress={onPress}>
      {uri ? <Image source={{ uri }} style={styles.image} /> : null}
      <View style={[styles.overlay, uri && styles.imageOverlay]}>
        <Ionicons color={uri ? "#FFFFFF" : "#0A0A0B"} name={uri ? "image" : "add"} size={24} />
        <Text style={[styles.label, uri && styles.imageLabel]}>{uploading ? "Uploading" : label}</Text>
      </View>
      {uri && onDelete ? (
        <Pressable accessibilityRole="button" hitSlop={10} style={styles.deleteButton} onPress={onDelete}>
          <Ionicons color="#FFFFFF" name="close" size={16} />
        </Pressable>
      ) : null}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  tile: {
    width: "48%",
    aspectRatio: 1,
    borderRadius: 18,
    borderWidth: 1,
    borderColor: "rgba(10,10,10,0.1)",
    backgroundColor: "#FFFFFF",
    overflow: "hidden"
  },
  image: {
    ...StyleSheet.absoluteFillObject
  },
  overlay: {
    ...StyleSheet.absoluteFillObject,
    alignItems: "center",
    justifyContent: "center",
    gap: 8
  },
  imageOverlay: {
    backgroundColor: "rgba(0,0,0,0.2)"
  },
  label: {
    color: "#0A0A0B",
    fontSize: 13,
    fontWeight: "900"
  },
  imageLabel: {
    color: "#FFFFFF"
  },
  deleteButton: {
    position: "absolute",
    top: 10,
    right: 10,
    width: 28,
    height: 28,
    borderRadius: 14,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "rgba(0,0,0,0.72)"
  }
});
