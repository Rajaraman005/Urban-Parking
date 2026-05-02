import type { NativeStackScreenProps } from "@react-navigation/native-stack";
import * as ImagePicker from "expo-image-picker";
import { useEffect, useState } from "react";
import { StyleSheet, Text, View } from "react-native";

import type { RootStackParamList } from "@/core/navigation/types";
import { toAuthError } from "@/features/auth/services/authErrors";
import { PhotoTile } from "@/features/userSetup/components/PhotoTile";
import { SetupScaffold } from "@/features/userSetup/components/SetupScaffold";
import { userSetupService } from "@/features/userSetup/services/userSetupService";
import { useUserSetupStore } from "@/features/userSetup/store/userSetupStore";
import type { ParkingSpace, ParkingSpacePhoto } from "@/features/userSetup/types/userSetup.types";

type Props = NativeStackScreenProps<RootStackParamList, "HostSpacePhotos">;

export function HostSpacePhotosScreen({ navigation, route }: Props) {
  const setDraft = useUserSetupStore((state) => state.setDraft);
  const setStorePhotos = useUserSetupStore((state) => state.setPhotos);
  const [draft, setLocalDraft] = useState<ParkingSpace | null>(null);
  const [photos, setPhotos] = useState<ParkingSpacePhoto[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [uploading, setUploading] = useState(false);
  const [isSaving, setIsSaving] = useState(false);

  useEffect(() => {
    let isMounted = true;

    const load = async () => {
      try {
        const snapshot = await userSetupService.loadDraftWithPhotos(route.params.draftId);

        if (!isMounted) {
          return;
        }

        setDraft(snapshot.draft);
        setLocalDraft(snapshot.draft);
        setPhotos(snapshot.photos);
        setStorePhotos(snapshot.photos);
      } catch (loadError) {
        setError(toAuthError(loadError).message);
      }
    };

    void load();

    return () => {
      isMounted = false;
    };
  }, [route.params.draftId, setDraft, setStorePhotos]);

  const pickPhoto = async () => {
    if (!draft || uploading) {
      return;
    }

    setError(null);
    const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();

    if (!permission.granted) {
      setError("Allow photo access to upload parking space photos.");
      return;
    }

    const result = await ImagePicker.launchImageLibraryAsync({
      allowsEditing: false,
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      quality: 0.92
    });

    if (result.canceled || !result.assets[0]) {
      return;
    }

    setUploading(true);

    try {
      const uploaded = await userSetupService.uploadPhoto(draft.id, result.assets[0], photos.length);
      const nextPhotos = [...photos, uploaded];
      setPhotos(nextPhotos);
      setStorePhotos(nextPhotos);
    } catch (uploadError) {
      setError(toAuthError(uploadError).message);
    } finally {
      setUploading(false);
    }
  };

  const deletePhoto = async (photo: ParkingSpacePhoto) => {
    setError(null);

    try {
      await userSetupService.deletePhoto(photo);
      const nextPhotos = photos.filter((item) => item.id !== photo.id);
      setPhotos(nextPhotos);
      setStorePhotos(nextPhotos);
    } catch (deleteError) {
      setError(toAuthError(deleteError).message);
    }
  };

  const continueToReview = async () => {
    setError(null);
    setIsSaving(true);

    try {
      await userSetupService.markPhotosStepComplete(route.params.draftId);
      navigation.replace("HostSpaceReview", { draftId: route.params.draftId });
    } catch (saveError) {
      setError(toAuthError(saveError).message);
    } finally {
      setIsSaving(false);
    }
  };

  return (
    <SetupScaffold
      description="Upload clear photos of entry, parking bay, and nearby approach. Photos are signed server-side before Cloudinary accepts them."
      error={error}
      primaryDisabled={!draft || photos.length === 0}
      primaryLabel="Review listing"
      primaryLoading={isSaving}
      progress={0.8}
      title="Add photos"
      onBack={() => navigation.replace("HostSpacePricing", { draftId: route.params.draftId })}
      onPrimaryPress={continueToReview}
    >
      <Text style={styles.meta}>{photos.length}/6 photos uploaded</Text>
      <View style={styles.grid}>
        {photos.map((photo) => (
          <PhotoTile
            key={photo.id}
            label="Uploaded"
            uri={photo.secure_url}
            onDelete={() => void deletePhoto(photo)}
          />
        ))}
        {photos.length < 6 ? <PhotoTile uploading={uploading} onPress={pickPhoto} /> : null}
      </View>
    </SetupScaffold>
  );
}

const styles = StyleSheet.create({
  meta: {
    color: "#666666",
    fontSize: 13,
    fontWeight: "800"
  },
  grid: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 12
  }
});
