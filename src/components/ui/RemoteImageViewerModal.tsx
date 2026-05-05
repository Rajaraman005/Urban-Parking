import { Ionicons } from "@expo/vector-icons";
import { usePreventScreenCapture } from "expo-screen-capture";
import { StatusBar } from "expo-status-bar";
import { useEffect, useMemo, useRef, useState } from "react";
import {
  Image,
  Modal,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
  useWindowDimensions
} from "react-native";
import { SafeAreaView } from "react-native-safe-area-context";

interface RemoteImageViewerModalProps {
  imageUrls: readonly string[];
  initialIndex?: number;
  onClose: () => void;
  visible: boolean;
}

const FALLBACK_IMAGE_URL =
  "https://images.unsplash.com/photo-1506521781263-d8422e82f27a";

export function RemoteImageViewerModal({
  imageUrls,
  initialIndex = 0,
  onClose,
  visible
}: RemoteImageViewerModalProps) {
  const displayUrls = useMemo(() => {
    const urls = new Set<string>();
    for (const rawUrl of imageUrls) {
      const url = rawUrl.trim();
      if (url) urls.add(url);
    }
    if (urls.size === 0) {
      urls.add(FALLBACK_IMAGE_URL);
    }
    return [...urls];
  }, [imageUrls]);

  return (
    <Modal
      animationType="fade"
      hardwareAccelerated
      onRequestClose={onClose}
      presentationStyle="fullScreen"
      statusBarTranslucent
      transparent={false}
      visible={visible}
    >
      {visible ? (
        <ProtectedImageViewerContent
          imageUrls={displayUrls}
          initialIndex={initialIndex}
          onClose={onClose}
        />
      ) : null}
    </Modal>
  );
}

function ProtectedImageViewerContent({
  imageUrls,
  initialIndex = 0,
  onClose
}: Omit<RemoteImageViewerModalProps, "visible">) {
  usePreventScreenCapture("parking-image-viewer");

  const scrollRef = useRef<ScrollView>(null);
  const { height: windowHeight, width: windowWidth } = useWindowDimensions();
  const pageWidth = Math.max(Math.round(windowWidth), 1);
  const [activeIndex, setActiveIndex] = useState(0);

  useEffect(() => {
    const safeIndex = Math.min(Math.max(initialIndex, 0), imageUrls.length - 1);
    setActiveIndex(safeIndex);
    requestAnimationFrame(() => {
      scrollRef.current?.scrollTo({ x: safeIndex * pageWidth, animated: false });
    });
  }, [imageUrls.length, initialIndex, pageWidth]);

  const imageHeight = Math.max(windowHeight - 132, 240);

  return (
    <SafeAreaView edges={["top", "bottom"]} style={styles.safeArea}>
      <StatusBar backgroundColor="#000000" style="light" translucent />
      <View style={styles.header}>
        <Pressable
          accessibilityLabel="Back"
          accessibilityRole="button"
          hitSlop={10}
          onPress={onClose}
          style={styles.backButton}
        >
          <Ionicons color="#FFFFFF" name="arrow-back" size={22} />
        </Pressable>
        <View style={styles.counter}>
          <Text style={styles.counterText}>
            {activeIndex + 1} / {imageUrls.length}
          </Text>
        </View>
      </View>

      <View style={styles.viewerBody}>
        <ScrollView
          ref={scrollRef}
          horizontal
          pagingEnabled
          showsHorizontalScrollIndicator={false}
          onMomentumScrollEnd={(event) => {
            const nextIndex = Math.round(event.nativeEvent.contentOffset.x / pageWidth);
            setActiveIndex(Math.min(Math.max(nextIndex, 0), imageUrls.length - 1));
          }}
        >
          {imageUrls.map((imageUrl, index) => (
            <View
              key={`${imageUrl}-${index}`}
              style={[
                styles.slide,
                {
                  height: imageHeight,
                  width: pageWidth
                }
              ]}
            >
              <Image
                resizeMode="contain"
                source={{ uri: imageUrl }}
                style={[
                  styles.viewerImage,
                  {
                    height: imageHeight,
                    width: pageWidth
                  }
                ]}
              />
            </View>
          ))}
        </ScrollView>
      </View>

      {imageUrls.length > 1 ? (
        <View style={styles.dots}>
          {imageUrls.map((_, index) => (
            <View
              key={`viewer-dot-${index}`}
              style={[
                styles.dot,
                {
                  backgroundColor:
                    index === activeIndex
                      ? "rgba(255,255,255,0.96)"
                      : "rgba(255,255,255,0.40)",
                  width: index === activeIndex ? 18 : 6
                }
              ]}
            />
          ))}
        </View>
      ) : null}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  backButton: {
    alignItems: "center",
    backgroundColor: "rgba(255,255,255,0.12)",
    borderColor: "rgba(255,255,255,0.18)",
    borderRadius: 999,
    borderWidth: 1,
    height: 44,
    justifyContent: "center",
    width: 44
  },
  counter: {
    backgroundColor: "rgba(255,255,255,0.10)",
    borderColor: "rgba(255,255,255,0.14)",
    borderRadius: 999,
    borderWidth: 1,
    paddingHorizontal: 12,
    paddingVertical: 8
  },
  counterText: {
    color: "#FFFFFF",
    fontSize: 12,
    fontWeight: "800"
  },
  dot: {
    borderRadius: 999,
    height: 6,
    marginHorizontal: 3
  },
  dots: {
    alignItems: "center",
    alignSelf: "center",
    backgroundColor: "rgba(255,255,255,0.10)",
    borderColor: "rgba(255,255,255,0.12)",
    borderRadius: 999,
    borderWidth: 1,
    flexDirection: "row",
    marginBottom: 24,
    paddingHorizontal: 9,
    paddingVertical: 7
  },
  header: {
    alignItems: "center",
    flexDirection: "row",
    justifyContent: "space-between",
    paddingHorizontal: 20,
    paddingTop: 8
  },
  safeArea: {
    backgroundColor: "#000000",
    flex: 1
  },
  slide: {
    alignItems: "center",
    justifyContent: "center"
  },
  viewerBody: {
    flex: 1,
    justifyContent: "center"
  },
  viewerImage: {
    backgroundColor: "#000000"
  }
});
