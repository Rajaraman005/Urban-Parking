import AsyncStorage from "@react-native-async-storage/async-storage";
import * as Crypto from "expo-crypto";
import * as SecureStore from "expo-secure-store";
import { Platform } from "react-native";

const DEVICE_FINGERPRINT_KEY = "urban_parking.device_fingerprint.v1";

export const getDeviceFingerprint = async () => {
  const existing =
    Platform.OS === "web"
      ? await AsyncStorage.getItem(DEVICE_FINGERPRINT_KEY)
      : await SecureStore.getItemAsync(DEVICE_FINGERPRINT_KEY);

  if (existing) {
    return existing;
  }

  const fingerprint = Crypto.randomUUID();

  if (Platform.OS === "web") {
    await AsyncStorage.setItem(DEVICE_FINGERPRINT_KEY, fingerprint);
    return fingerprint;
  }

  await SecureStore.setItemAsync(DEVICE_FINGERPRINT_KEY, fingerprint, {
    keychainAccessible: SecureStore.WHEN_UNLOCKED_THIS_DEVICE_ONLY
  });

  return fingerprint;
};
