import { Ionicons } from "@expo/vector-icons";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { ActivityIndicator, Pressable, StyleSheet, View, type StyleProp, type ViewStyle } from "react-native";
import WebView, { type WebViewMessageEvent } from "react-native-webview";

const INDIA_BOUNDS = {
  maxLatitude: 38,
  maxLongitude: 98,
  minLatitude: 6,
  minLongitude: 68
} as const;

type BridgeMessage =
  | { type: "map_ready" }
  | { latitude: number; longitude: number; type: "pin_changed" }
  | { latitude: number; longitude: number; type: "pin_confirmed" };

interface Coordinates {
  latitude: number;
  longitude: number;
}

interface OpenStreetAddressPickerProps {
  confirmed?: boolean;
  isLocating?: boolean;
  isBusy?: boolean;
  latitude?: number | null;
  longitude?: number | null;
  mapShellStyle?: StyleProp<ViewStyle>;
  showLocateButton?: boolean;
  style?: StyleProp<ViewStyle>;
  onMapReady?: () => void;
  onPinChanged: (coordinates: Coordinates) => void;
  onPinConfirmed: (coordinates: Coordinates) => void;
  onUseCurrentLocation?: () => void;
}

const isIndiaCoordinate = (latitude: number, longitude: number) =>
  Number.isFinite(latitude) &&
  Number.isFinite(longitude) &&
  latitude >= INDIA_BOUNDS.minLatitude &&
  latitude <= INDIA_BOUNDS.maxLatitude &&
  longitude >= INDIA_BOUNDS.minLongitude &&
  longitude <= INDIA_BOUNDS.maxLongitude;

const isBridgeMessage = (payload: unknown): payload is BridgeMessage => {
  if (!payload || typeof payload !== "object") {
    return false;
  }

  const message = payload as Partial<BridgeMessage>;

  if (message.type === "map_ready") {
    return true;
  }

  if (message.type !== "pin_changed" && message.type !== "pin_confirmed") {
    return false;
  }

  return (
    typeof message.latitude === "number" &&
    typeof message.longitude === "number" &&
    isIndiaCoordinate(message.latitude, message.longitude)
  );
};

const createMapHtml = (latitude?: number | null, longitude?: number | null) => {
  const hasPin = typeof latitude === "number" && typeof longitude === "number" && isIndiaCoordinate(latitude, longitude);
  const initialLatitude = hasPin ? latitude : 20.5937;
  const initialLongitude = hasPin ? longitude : 78.9629;
  const initialZoom = hasPin ? 16 : 5;

  return `<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="initial-scale=1, maximum-scale=1, minimum-scale=1, width=device-width" />
    <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
    <style>
      html, body, #map {
        height: 100%;
        margin: 0;
        padding: 0;
        width: 100%;
        background: #f4f4f4;
        font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
      }
      .leaflet-control-attribution {
        font-size: 10px;
        font-weight: 700;
      }
      .location-marker {
        width: 34px !important;
        height: 44px !important;
        border: 0 !important;
        background: transparent !important;
        box-sizing: border-box;
      }
      .location-marker svg {
        display: block;
        filter: drop-shadow(0 6px 10px rgba(0, 0, 0, 0.3));
      }
    </style>
  </head>
  <body>
    <div id="map"></div>
    <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
    <script>
      (function () {
        const bounds = {
          minLatitude: ${INDIA_BOUNDS.minLatitude},
          maxLatitude: ${INDIA_BOUNDS.maxLatitude},
          minLongitude: ${INDIA_BOUNDS.minLongitude},
          maxLongitude: ${INDIA_BOUNDS.maxLongitude}
        };
        const initial = { latitude: ${initialLatitude}, longitude: ${initialLongitude}, zoom: ${initialZoom} };
        const map = L.map("map", {
          attributionControl: true,
          preferCanvas: true,
          zoomControl: false
        }).setView([initial.latitude, initial.longitude], initial.zoom);
        const indiaBounds = L.latLngBounds(
          [bounds.minLatitude, bounds.minLongitude],
          [bounds.maxLatitude, bounds.maxLongitude]
        );
        let marker = null;
        const locationIcon = L.divIcon({
          className: "location-marker",
          html: '<svg width="34" height="44" viewBox="0 0 34 44" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M17 42C17 42 31 28.9 31 17C31 8.8 24.7 2.5 17 2.5C9.3 2.5 3 8.8 3 17C3 28.9 17 42 17 42Z" fill="#0A0A0B" stroke="#FFFFFF" stroke-width="3" stroke-linejoin="round"/><circle cx="17" cy="17" r="6" fill="#FFFFFF"/></svg>',
          iconAnchor: [17, 42],
          iconSize: [34, 44]
        });

        L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
          attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap contributors</a>',
          maxZoom: 19,
          minZoom: 4,
          noWrap: true,
          updateWhenIdle: true,
          updateWhenZooming: false,
          keepBuffer: 1
        }).addTo(map);

        map.setMaxBounds(indiaBounds.pad(0.15));

        function isValid(latitude, longitude) {
          return Number.isFinite(latitude) &&
            Number.isFinite(longitude) &&
            latitude >= bounds.minLatitude &&
            latitude <= bounds.maxLatitude &&
            longitude >= bounds.minLongitude &&
            longitude <= bounds.maxLongitude;
        }

        function post(message) {
          window.ReactNativeWebView && window.ReactNativeWebView.postMessage(JSON.stringify(message));
        }

        function markerCoordinates() {
          if (!marker) {
            return null;
          }
          const point = marker.getLatLng();
          return { latitude: point.lat, longitude: point.lng };
        }

        function setPin(latitude, longitude, zoom, emit) {
          if (!isValid(latitude, longitude)) {
            return;
          }
          const point = [latitude, longitude];

          if (!marker) {
            marker = L.marker(point, {
              autoPan: true,
              draggable: true,
              icon: locationIcon
            }).addTo(map);
            marker.on("dragend", function () {
              const next = markerCoordinates();
              if (next && isValid(next.latitude, next.longitude)) {
                post({ type: "pin_changed", latitude: next.latitude, longitude: next.longitude });
              }
            });
          } else {
            marker.setLatLng(point);
          }

          map.setView(point, zoom || Math.max(map.getZoom(), 16), { animate: true });

          if (emit) {
            post({ type: "pin_changed", latitude, longitude });
          }
        }

        ${hasPin ? "setPin(initial.latitude, initial.longitude, initial.zoom, false);" : ""}

        map.on("click", function (event) {
          const latitude = event.latlng.lat;
          const longitude = event.latlng.lng;
          setPin(latitude, longitude, 16, true);
        });

        function handleNativeMessage(event) {
          try {
            const message = JSON.parse(event.data);
            if (message && message.type === "set_pin") {
              setPin(Number(message.latitude), Number(message.longitude), Number(message.zoom) || 16, false);
            }
          } catch (_error) {}
        }

        window.addEventListener("message", handleNativeMessage);
        document.addEventListener("message", handleNativeMessage);
        setTimeout(function () {
          map.invalidateSize();
          post({ type: "map_ready" });
        }, 250);
      })();
    </script>
  </body>
</html>`;
};

export function OpenStreetAddressPicker({
  isLocating,
  isBusy,
  latitude,
  longitude,
  mapShellStyle,
  showLocateButton = true,
  style,
  onMapReady,
  onPinChanged,
  onPinConfirmed,
  onUseCurrentLocation
}: OpenStreetAddressPickerProps) {
  const webViewRef = useRef<WebView>(null);
  const [isMapReady, setIsMapReady] = useState(false);
  const html = useMemo(() => createMapHtml(), []);

  useEffect(() => {
    if (!isMapReady || typeof latitude !== "number" || typeof longitude !== "number" || !isIndiaCoordinate(latitude, longitude)) {
      return;
    }

    webViewRef.current?.postMessage(
      JSON.stringify({
        latitude,
        longitude,
        type: "set_pin",
        zoom: 16
      })
    );
  }, [isMapReady, latitude, longitude]);

  const handleMessage = useCallback(
    (event: WebViewMessageEvent) => {
      let payload: unknown;

      try {
        payload = JSON.parse(event.nativeEvent.data);
      } catch {
        return;
      }

      if (!isBridgeMessage(payload)) {
        return;
      }

      if (payload.type === "map_ready") {
        setIsMapReady(true);
        onMapReady?.();
        return;
      }

      if (payload.type === "pin_changed") {
        onPinChanged({ latitude: payload.latitude, longitude: payload.longitude });
        return;
      }

      onPinConfirmed({ latitude: payload.latitude, longitude: payload.longitude });
    },
    [onMapReady, onPinChanged, onPinConfirmed]
  );

  return (
    <View style={[styles.wrapper, style]}>
      <View style={[styles.mapShell, mapShellStyle]}>
        <WebView
          ref={webViewRef}
          allowFileAccess={false}
          allowsBackForwardNavigationGestures={false}
          allowsFullscreenVideo={false}
          applicationNameForUserAgent="UrbanParking/1.0"
          bounces={false}
          cacheEnabled
          domStorageEnabled={false}
          javaScriptEnabled
          mixedContentMode="never"
          originWhitelist={["*"]}
          scrollEnabled={false}
          source={{ html }}
          style={styles.webView}
          textInteractionEnabled={false}
          onMessage={handleMessage}
          onShouldStartLoadWithRequest={(request) => {
            const url = request.url;

            return (
              url === "about:blank" ||
              url.startsWith("data:") ||
              url.startsWith("https://unpkg.com/leaflet@1.9.4/") ||
              url.startsWith("https://tile.openstreetmap.org/")
            );
          }}
        />
        {showLocateButton && onUseCurrentLocation ? (
          <Pressable
            accessibilityRole="button"
            disabled={Boolean(isLocating || isBusy)}
            style={styles.locateButton}
            onPress={onUseCurrentLocation}
          >
            {isLocating || isBusy ? (
              <ActivityIndicator color="#0A0A0B" size="small" />
            ) : (
              <Ionicons color="#0A0A0B" name="locate" size={24} />
            )}
          </Pressable>
        ) : null}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrapper: {
    gap: 10
  },
  mapShell: {
    height: 318,
    overflow: "hidden",
    borderRadius: 0,
    backgroundColor: "#F5F5F5"
  },
  webView: {
    flex: 1,
    backgroundColor: "#F5F5F5"
  },
  locateButton: {
    position: "absolute",
    right: 16,
    bottom: 18,
    width: 54,
    height: 54,
    alignItems: "center",
    justifyContent: "center",
    borderRadius: 27,
    backgroundColor: "#FFFFFF",
    shadowColor: "#000000",
    shadowOpacity: 0.16,
    shadowRadius: 14,
    shadowOffset: { height: 8, width: 0 },
    elevation: 8
  },
});
