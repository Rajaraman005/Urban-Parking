import AsyncStorage from "@react-native-async-storage/async-storage";
import * as SecureStore from "expo-secure-store";
import { Platform } from "react-native";

interface SupabaseStorage {
  getItem: (key: string) => Promise<string | null>;
  setItem: (key: string, value: string) => Promise<void>;
  removeItem: (key: string) => Promise<void>;
}

const secureStoreOptions: SecureStore.SecureStoreOptions = {
  keychainAccessible: SecureStore.WHEN_UNLOCKED_THIS_DEVICE_ONLY
};

const CHUNK_SIZE = 1800;
const chunkMetaKey = (key: string) => `${key}.chunk_count`;
const chunkKey = (key: string, index: number) => `${key}.chunk.${index}`;

const getSecureItem = (key: string) => SecureStore.getItemAsync(key, secureStoreOptions);
const setSecureItem = (key: string, value: string) => SecureStore.setItemAsync(key, value, secureStoreOptions);
const deleteSecureItem = (key: string) => SecureStore.deleteItemAsync(key, secureStoreOptions);

const deleteChunks = async (key: string) => {
  const countValue = await getSecureItem(chunkMetaKey(key));
  const count = Number(countValue ?? 0);

  if (Number.isFinite(count) && count > 0) {
    await Promise.all(
      Array.from({ length: count }, (_, index) => deleteSecureItem(chunkKey(key, index)).catch(() => undefined))
    );
  }

  await deleteSecureItem(chunkMetaKey(key)).catch(() => undefined);
};

export const supabaseSecureStorage: SupabaseStorage = {
  async getItem(key) {
    if (Platform.OS === "web") {
      return AsyncStorage.getItem(key);
    }

    const countValue = await getSecureItem(chunkMetaKey(key));
    const count = Number(countValue ?? 0);

    if (Number.isFinite(count) && count > 0) {
      const chunks = await Promise.all(Array.from({ length: count }, (_, index) => getSecureItem(chunkKey(key, index))));

      if (chunks.some((chunk) => chunk === null)) {
        await deleteChunks(key);
        return null;
      }

      return chunks.join("");
    }

    return getSecureItem(key);
  },
  async setItem(key, value) {
    if (Platform.OS === "web") {
      await AsyncStorage.setItem(key, value);
      return;
    }

    await deleteChunks(key);

    if (value.length <= CHUNK_SIZE) {
      await setSecureItem(key, value);
      return;
    }

    await deleteSecureItem(key).catch(() => undefined);

    const chunks = value.match(new RegExp(`.{1,${CHUNK_SIZE}}`, "g")) ?? [];
    await Promise.all(chunks.map((chunk, index) => setSecureItem(chunkKey(key, index), chunk)));
    await setSecureItem(chunkMetaKey(key), String(chunks.length));
  },
  async removeItem(key) {
    if (Platform.OS === "web") {
      await AsyncStorage.removeItem(key);
      return;
    }

    await deleteChunks(key);
    await deleteSecureItem(key).catch(() => undefined);
  }
};
