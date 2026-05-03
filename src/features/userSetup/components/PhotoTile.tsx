import { Ionicons } from "@expo/vector-icons";
import { ActivityIndicator, Image, Pressable, StyleSheet, Text, View } from "react-native";
import { useState } from "react";

interface PhotoTileProps {
  uri?: string;
  label?: string;
  helperText?: string;
  uploading?: boolean;
  onPress?: () => void;
  onDelete?: () => void;
  disabled?: boolean;
  compact?: boolean;
}

export function PhotoTile({
  disabled,
  helperText,
  label = "Add photo",
  onDelete,
  onPress,
  uploading,
  uri,
  compact
}: PhotoTileProps) {
  const [imageFailed, setImageFailed] = useState(false);
  const hasVisual = Boolean(uri) && !imageFailed;
  const showPreviewChrome = hasVisual && !uploading;

  return (
    <Pressable
      accessibilityRole="button"
      disabled={disabled || uploading}
      style={[styles.tile, compact ? styles.tileCompact : null, disabled ? styles.tileDisabled : null]}
      onPress={onPress}
    >
      {hasVisual ? <Image source={{ uri }} style={styles.image} onError={() => setImageFailed(true)} /> : null}
      {!showPreviewChrome ? (
        <View style={[styles.overlay, hasVisual ? styles.imageOverlay : styles.emptyOverlay]}>
          {uploading ? (
            <ActivityIndicator color={hasVisual ? "#FFFFFF" : "#0A0A0B"} />
          ) : (
            <Ionicons color={hasVisual ? "#FFFFFF" : "#0A0A0B"} name={hasVisual ? "image-outline" : "add"} size={compact ? 20 : 24} />
          )}
          <Text style={[styles.label, compact ? styles.labelCompact : null, hasVisual && styles.imageLabel]}>{uploading ? "Uploading photo" : label}</Text>
          {helperText ? (
            <Text style={[styles.helperText, compact ? styles.helperTextCompact : null, hasVisual && styles.imageHelperText]}>{helperText}</Text>
          ) : null}
        </View>
      ) : null}
      {showPreviewChrome && helperText ? (
        <View style={styles.previewMeta}>
          <Text style={styles.previewMetaText}>{helperText}</Text>
        </View>
      ) : null}
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
    borderRadius: 20,
    borderWidth: 1,
    borderColor: "rgba(10,10,10,0.08)",
    backgroundColor: "#F8F8FA",
    overflow: "hidden"
  },
  tileCompact: {
    width: "31.8%",
    borderRadius: 16
  },
  tileDisabled: {
    opacity: 0.62
  },
  image: {
    ...StyleSheet.absoluteFillObject
  },
  overlay: {
    ...StyleSheet.absoluteFillObject,
    alignItems: "center",
    justifyContent: "center",
    gap: 8,
    paddingHorizontal: 14
  },
  emptyOverlay: {
    borderStyle: "dashed",
    borderWidth: 1,
    borderColor: "rgba(10,10,10,0.08)",
    borderRadius: 20,
    margin: 10
  },
  imageOverlay: {
    backgroundColor: "rgba(0,0,0,0.22)"
  },
  label: {
    color: "#0A0A0B",
    fontSize: 14,
    fontWeight: "900",
    textAlign: "center"
  },
  imageLabel: {
    color: "#FFFFFF"
  },
  labelCompact: {
    fontSize: 12
  },
  helperText: {
    color: "#6A6A72",
    fontSize: 12,
    fontWeight: "700",
    lineHeight: 17,
    textAlign: "center"
  },
  imageHelperText: {
    color: "rgba(255,255,255,0.86)"
  },
  helperTextCompact: {
    fontSize: 11,
    lineHeight: 15
  },
  previewMeta: {
    position: "absolute",
    left: 8,
    right: 8,
    bottom: 8,
    borderRadius: 999,
    backgroundColor: "rgba(10,10,11,0.68)",
    paddingHorizontal: 10,
    paddingVertical: 6
  },
  previewMetaText: {
    color: "#FFFFFF",
    fontSize: 11,
    fontWeight: "800",
    textAlign: "center"
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
