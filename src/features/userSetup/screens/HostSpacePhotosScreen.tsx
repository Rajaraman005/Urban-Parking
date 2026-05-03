import { Ionicons } from "@expo/vector-icons";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";
import * as ImagePicker from "expo-image-picker";
import { useEffect, useMemo, useState } from "react";
import { Image, Linking, Modal, Pressable, ScrollView, StyleSheet, Text, View } from "react-native";

import type { RootStackParamList } from "@/core/navigation/types";
import { toAuthError } from "@/features/auth/services/authErrors";
import { SetupScaffold } from "@/features/userSetup/components/SetupScaffold";
import { userSetupService } from "@/features/userSetup/services/userSetupService";
import { useUserSetupStore } from "@/features/userSetup/store/userSetupStore";
import type { ParkingSpace, ParkingSpacePhoto } from "@/features/userSetup/types/userSetup.types";

type Props = NativeStackScreenProps<RootStackParamList, "HostSpacePhotos">;

const MAX_PHOTOS = 5;
const MIN_PHOTOS = 2;
const recommendedShots = ["Entry", "Parking bay", "Approach"] as const;

interface PendingUploadTile {
  id: string;
  uri: string;
}

interface UploadedPhotoListItem {
  id: string;
  subtitle: string;
  title: string;
  uri: string;
}

export function HostSpacePhotosScreen({ navigation, route }: Props) {
  const setDraft = useUserSetupStore((state) => state.setDraft);
  const setStorePhotos = useUserSetupStore((state) => state.setPhotos);
  const [draft, setLocalDraft] = useState<ParkingSpace | null>(null);
  const [photos, setPhotos] = useState<ParkingSpacePhoto[]>([]);
  const [pendingUploads, setPendingUploads] = useState<PendingUploadTile[]>([]);
  const [previewUrisByPhotoId, setPreviewUrisByPhotoId] = useState<Record<string, string>>({});
  const [error, setError] = useState<string | null>(null);
  const [uploadingSource, setUploadingSource] = useState<"camera" | "gallery" | null>(null);
  const [isPickerSheetOpen, setIsPickerSheetOpen] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const canAddMore = photos.length < MAX_PHOTOS;
  const remainingSlots = Math.max(0, MAX_PHOTOS - photos.length);
  const canContinue = Boolean(draft) && photos.length >= MIN_PHOTOS && !uploadingSource;
  const progressLabel = `${photos.length} of ${MAX_PHOTOS} photos added`;
  const helperCopy =
    photos.length >= MIN_PHOTOS
      ? "Nice. You have enough photos to continue."
      : `Add at least ${MIN_PHOTOS} photos to continue.`;
  const showSettingsHelp = Boolean(error?.toLowerCase().includes("allow") || error?.toLowerCase().includes("permission"));
  const uploadedItems = useMemo<UploadedPhotoListItem[]>(
    () =>
      photos.map((photo, index) => ({
        id: photo.id,
        subtitle:
          typeof photo.width === "number" && typeof photo.height === "number"
            ? `${photo.width} x ${photo.height}`
            : "Uploaded",
        title: `Photo ${index + 1}`,
        uri: previewUrisByPhotoId[photo.id] ?? photo.secure_url
      })),
    [photos, previewUrisByPhotoId]
  );

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

  const uploadAssets = async (assets: ImagePicker.ImagePickerAsset[], source: "camera" | "gallery") => {
    if (!draft) {
      return;
    }

    const selectedAssets = assets.slice(0, remainingSlots);

    if (selectedAssets.length === 0) {
      return;
    }

    setUploadingSource(source);
    setError(null);
    const localPendingEntries = selectedAssets.map((asset, index) => ({
      id: `${source}-${Date.now()}-${index}`,
      uri: asset.uri
    }));
    setPendingUploads((current) => [...current, ...localPendingEntries]);

    try {
      let nextPhotos = [...photos];
      let firstErrorMessage: string | null = null;

      for (const [index, asset] of selectedAssets.entries()) {
        try {
          const uploaded = await userSetupService.uploadPhoto(draft.id, asset, nextPhotos.length);
          nextPhotos = [...nextPhotos, uploaded];
          setPhotos(nextPhotos);
          setStorePhotos(nextPhotos);
          setPreviewUrisByPhotoId((current) => ({ ...current, [uploaded.id]: asset.uri }));
        } catch (uploadError) {
          if (!firstErrorMessage) {
            firstErrorMessage = toAuthError(uploadError).message;
          }
        } finally {
          const pendingId = localPendingEntries[index]?.id;

          if (pendingId) {
            setPendingUploads((current) => current.filter((item) => item.id !== pendingId));
          }
        }
      }

      if (firstErrorMessage) {
        setError(firstErrorMessage);
      }
    } finally {
      setUploadingSource(null);
    }
  };

  const pickFromGallery = async () => {
    if (!draft || uploadingSource || !canAddMore) {
      return;
    }

    setError(null);
    const permission = await ImagePicker.requestMediaLibraryPermissionsAsync();

    if (!permission.granted) {
      setError("Allow gallery access to choose parking space photos.");
      return;
    }

    const result = await ImagePicker.launchImageLibraryAsync({
      allowsEditing: false,
      allowsMultipleSelection: true,
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      selectionLimit: remainingSlots,
      quality: 0.92
    });

    if (result.canceled || !result.assets.length) {
      return;
    }

    await uploadAssets(result.assets, "gallery");
  };

  const takePhoto = async () => {
    if (!draft || uploadingSource || !canAddMore) {
      return;
    }

    setError(null);
    const permission = await ImagePicker.requestCameraPermissionsAsync();

    if (!permission.granted) {
      setError("Allow camera access to take parking space photos.");
      return;
    }

    const result = await ImagePicker.launchCameraAsync({
      allowsEditing: false,
      cameraType: ImagePicker.CameraType.back,
      mediaTypes: ImagePicker.MediaTypeOptions.Images,
      quality: 0.92
    });

    if (result.canceled || !result.assets[0]) {
      return;
    }

    await uploadAssets([result.assets[0]], "camera");
  };

  const openUploadPicker = () => {
    if (!canAddMore || uploadingSource) {
      return;
    }

    setIsPickerSheetOpen(true);
  };

  const closeUploadPicker = () => {
    setIsPickerSheetOpen(false);
  };

  const handlePickerAction = (action: "camera" | "gallery") => {
    closeUploadPicker();

    if (action === "camera") {
      void takePhoto();
      return;
    }

    void pickFromGallery();
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
      error={error}
      primaryDisabled={!canContinue}
      primaryLabel="Review listing"
      primaryLoading={isSaving}
      progress={0.8}
      showAvatar={false}
      showIntro={false}
      title="Add photos"
      onBack={() => navigation.replace("HostSpacePricing", { draftId: route.params.draftId })}
      onPrimaryPress={continueToReview}
    >
      <View style={styles.pageHeader}>
        <Text style={styles.pageTitle}>Add photos</Text>
        <Text style={styles.pageSubtitle}>Show the entry, the parking bay, and the approach. Add at least 2 photos.</Text>
      </View>

      <Pressable
        accessibilityRole="button"
        disabled={!canAddMore || Boolean(uploadingSource)}
        style={[styles.uploadPanel, !canAddMore || Boolean(uploadingSource) ? styles.uploadPanelDisabled : null]}
        onPress={openUploadPicker}
      >
        <View style={styles.uploadIconWrap}>
          <Ionicons color="#0A0A0B" name="cloud-upload-outline" size={26} />
        </View>
        <Text style={styles.uploadPanelTitle}>
          {uploadingSource ? "Uploading photos..." : canAddMore ? "Tap to upload photos" : "Photo limit reached"}
        </Text>
        <Text style={styles.uploadPanelBody}>
          {uploadingSource
            ? "Please wait while your selected photos are added below."
            : canAddMore
              ? "Open your phone picker to choose camera or gallery."
              : "You already added the maximum 5 photos."}
        </Text>
        <View style={styles.hintRow}>
          {recommendedShots.map((shot) => (
            <View key={shot} style={styles.hintChip}>
              <Text style={styles.hintChipText}>{shot}</Text>
            </View>
          ))}
        </View>
      </Pressable>

      <View style={styles.countRow}>
        <Text style={styles.countTitle}>Uploaded photos</Text>
        <Text style={styles.countValue}>{progressLabel}</Text>
      </View>
      <View style={styles.progressTrack}>
        <View style={[styles.progressFill, { width: `${Math.max((photos.length / MAX_PHOTOS) * 100, 8)}%` }]} />
      </View>
      <Text style={styles.progressCaption}>{helperCopy}</Text>

      {showSettingsHelp ? (
        <Pressable accessibilityRole="button" style={styles.settingsCard} onPress={() => void Linking.openSettings()}>
          <Ionicons color="#0A0A0B" name="settings-outline" size={18} />
          <Text style={styles.settingsText}>Open app settings</Text>
        </Pressable>
      ) : null}

      <ScrollView contentContainerStyle={styles.uploadedList} showsVerticalScrollIndicator={false}>
        {pendingUploads.map((item, index) => (
          <UploadedPhotoRow
            key={item.id}
            subtitle="Preparing upload"
            title={`Uploading ${index + 1}`}
            uri={item.uri}
            uploading
          />
        ))}
        {uploadedItems.map((item, index) => (
          <UploadedPhotoRow
            key={item.id}
            subtitle={item.subtitle}
            title={item.title}
            uri={item.uri}
            onDelete={() => void deletePhoto(photos[index] as ParkingSpacePhoto)}
          />
        ))}
        {!pendingUploads.length && !uploadedItems.length ? (
          <View style={styles.emptyState}>
            <Ionicons color="#8A8A92" name="images-outline" size={20} />
            <Text style={styles.emptyStateText}>Your uploaded photos will appear here.</Text>
          </View>
        ) : null}
      </ScrollView>

      <Modal
        animationType="slide"
        onRequestClose={closeUploadPicker}
        transparent
        visible={isPickerSheetOpen}
      >
        <View style={styles.sheetRoot}>
          <Pressable style={styles.sheetBackdrop} onPress={closeUploadPicker} />
          <View style={styles.sheetCard}>
            <View style={styles.sheetHandle} />
            <Text style={styles.sheetTitle}>Add photos</Text>
            <Text style={styles.sheetSubtitle}>Choose how you want to add parking photos.</Text>

            <Pressable accessibilityRole="button" style={styles.sheetOption} onPress={() => handlePickerAction("camera")}>
              <View style={styles.sheetOptionIcon}>
                <Ionicons color="#0A0A0B" name="camera-outline" size={20} />
              </View>
              <View style={styles.sheetOptionCopy}>
                <Text style={styles.sheetOptionTitle}>Take photo</Text>
                <Text style={styles.sheetOptionSubtitle}>Open the camera and capture the space</Text>
              </View>
              <Ionicons color="#8A8A92" name="chevron-forward" size={20} />
            </Pressable>

            <Pressable accessibilityRole="button" style={styles.sheetOption} onPress={() => handlePickerAction("gallery")}>
              <View style={styles.sheetOptionIcon}>
                <Ionicons color="#0A0A0B" name="images-outline" size={20} />
              </View>
              <View style={styles.sheetOptionCopy}>
                <Text style={styles.sheetOptionTitle}>Choose from gallery</Text>
                <Text style={styles.sheetOptionSubtitle}>Pick one or more saved photos</Text>
              </View>
              <Ionicons color="#8A8A92" name="chevron-forward" size={20} />
            </Pressable>

            <Pressable accessibilityRole="button" style={styles.sheetCancelButton} onPress={closeUploadPicker}>
              <Text style={styles.sheetCancelText}>Cancel</Text>
            </Pressable>
          </View>
        </View>
      </Modal>
    </SetupScaffold>
  );
}

function UploadedPhotoRow({
  onDelete,
  subtitle,
  title,
  uploading,
  uri
}: {
  title: string;
  subtitle: string;
  uri: string;
  uploading?: boolean;
  onDelete?: () => void;
}) {
  const [imageFailed, setImageFailed] = useState(false);

  return (
    <View style={styles.uploadedRow}>
      <View style={styles.thumbnailWrap}>
        {!imageFailed ? (
          <Image source={{ uri }} style={styles.thumbnail} onError={() => setImageFailed(true)} />
        ) : (
          <View style={styles.thumbnailFallback}>
            <Ionicons color="#8A8A92" name="image-outline" size={18} />
          </View>
        )}
      </View>
      <View style={styles.uploadedCopy}>
        <Text numberOfLines={1} style={styles.uploadedTitle}>
          {title}
        </Text>
        <Text numberOfLines={1} style={styles.uploadedSubtitle}>
          {uploading ? "Uploading photo..." : subtitle}
        </Text>
      </View>
      {onDelete ? (
        <Pressable accessibilityRole="button" hitSlop={8} style={styles.rowDeleteButton} onPress={onDelete}>
          <Ionicons color="#0A0A0B" name="close" size={18} />
        </Pressable>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  pageHeader: {
    gap: 16,
    paddingTop: 4
  },
  pageTitle: {
    color: "#0A0A0B",
    fontSize: 26,
    fontWeight: "900",
    lineHeight: 30
  },
  pageSubtitle: {
    color: "#66666D",
    fontSize: 14,
    fontWeight: "700",
    lineHeight: 21
  },
  uploadPanel: {
    alignItems: "center",
    gap: 14,
    paddingHorizontal: 18,
    paddingVertical: 24,
    borderRadius: 22,
    backgroundColor: "#F5F4FB",
    borderWidth: 1,
    borderColor: "#B7B1D1",
    borderStyle: "dashed"
  },
  uploadPanelDisabled: {
    opacity: 0.68
  },
  uploadIconWrap: {
    width: 52,
    height: 52,
    borderRadius: 26,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#FFFFFF"
  },
  uploadPanelTitle: {
    color: "#0A0A0B",
    fontSize: 17,
    fontWeight: "900"
  },
  uploadPanelBody: {
    color: "#6A6A72",
    fontSize: 13,
    fontWeight: "700",
    lineHeight: 18,
    textAlign: "center"
  },
  countPill: {
    alignItems: "center",
    flexDirection: "row",
    gap: 8,
    backgroundColor: "#FFFFFF",
    borderRadius: 999,
    paddingHorizontal: 12,
    paddingVertical: 8
  },
  countPillText: {
    color: "#0A0A0B",
    fontSize: 13,
    fontWeight: "800"
  },
  countRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center"
  },
  countTitle: {
    color: "#0A0A0B",
    fontSize: 16,
    fontWeight: "900"
  },
  countValue: {
    color: "#6A6A72",
    fontSize: 13,
    fontWeight: "800"
  },
  progressTrack: {
    height: 8,
    borderRadius: 999,
    backgroundColor: "#E4E4E8",
    overflow: "hidden"
  },
  progressFill: {
    height: 8,
    borderRadius: 999,
    backgroundColor: "#0A0A0B"
  },
  progressCaption: {
    color: "#66666D",
    fontSize: 13,
    fontWeight: "700"
  },
  hintRow: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 10
  },
  hintChip: {
    backgroundColor: "#FFFFFF",
    borderRadius: 999,
    paddingHorizontal: 12,
    paddingVertical: 8
  },
  hintChipText: {
    color: "#0A0A0B",
    fontSize: 12,
    fontWeight: "800"
  },
  settingsCard: {
    minHeight: 52,
    borderRadius: 18,
    backgroundColor: "#F7F7F8",
    borderWidth: 1,
    borderColor: "#ECECEF",
    paddingHorizontal: 16,
    flexDirection: "row",
    alignItems: "center",
    gap: 10
  },
  settingsText: {
    color: "#0A0A0B",
    fontSize: 14,
    fontWeight: "800"
  },
  uploadedList: {
    gap: 12,
    paddingBottom: 8
  },
  uploadedRow: {
    minHeight: 84,
    borderRadius: 20,
    borderWidth: 1,
    borderColor: "#ECECEF",
    backgroundColor: "#FFFFFF",
    paddingHorizontal: 14,
    paddingVertical: 12,
    flexDirection: "row",
    alignItems: "center",
    gap: 12
  },
  thumbnailWrap: {
    width: 60,
    height: 60,
    borderRadius: 14,
    overflow: "hidden",
    backgroundColor: "#F3F4F6"
  },
  thumbnail: {
    width: "100%",
    height: "100%"
  },
  thumbnailFallback: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center"
  },
  uploadedCopy: {
    flex: 1,
    gap: 4
  },
  uploadedTitle: {
    color: "#0A0A0B",
    fontSize: 14,
    fontWeight: "900"
  },
  uploadedSubtitle: {
    color: "#6A6A72",
    fontSize: 12,
    fontWeight: "700"
  },
  rowDeleteButton: {
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#F4F4F6"
  },
  emptyState: {
    minHeight: 84,
    borderRadius: 20,
    borderWidth: 1,
    borderStyle: "dashed",
    borderColor: "#D8DAE0",
    backgroundColor: "#FCFCFD",
    alignItems: "center",
    justifyContent: "center",
    gap: 8,
    paddingHorizontal: 16
  },
  emptyStateText: {
    color: "#8A8A92",
    fontSize: 13,
    fontWeight: "700",
    textAlign: "center"
  },
  sheetRoot: {
    flex: 1,
    justifyContent: "flex-end"
  },
  sheetBackdrop: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: "rgba(10, 10, 11, 0.28)"
  },
  sheetCard: {
    borderTopLeftRadius: 28,
    borderTopRightRadius: 28,
    backgroundColor: "#FFFFFF",
    paddingHorizontal: 20,
    paddingTop: 10,
    paddingBottom: 28,
    gap: 14
  },
  sheetHandle: {
    alignSelf: "center",
    width: 42,
    height: 5,
    borderRadius: 999,
    backgroundColor: "#D4D4DA",
    marginBottom: 6
  },
  sheetTitle: {
    color: "#0A0A0B",
    fontSize: 20,
    fontWeight: "900",
    textAlign: "center"
  },
  sheetSubtitle: {
    color: "#6A6A72",
    fontSize: 14,
    fontWeight: "700",
    lineHeight: 20,
    textAlign: "center",
    marginBottom: 4
  },
  sheetOption: {
    minHeight: 78,
    borderRadius: 20,
    borderWidth: 1,
    borderColor: "#ECECEF",
    backgroundColor: "#FBFBFC",
    paddingHorizontal: 16,
    flexDirection: "row",
    alignItems: "center",
    gap: 14
  },
  sheetOptionIcon: {
    width: 44,
    height: 44,
    borderRadius: 22,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#FFFFFF"
  },
  sheetOptionCopy: {
    flex: 1,
    gap: 2
  },
  sheetOptionTitle: {
    color: "#0A0A0B",
    fontSize: 15,
    fontWeight: "900"
  },
  sheetOptionSubtitle: {
    color: "#6A6A72",
    fontSize: 12,
    fontWeight: "700",
    lineHeight: 17
  },
  sheetCancelButton: {
    minHeight: 54,
    borderRadius: 18,
    alignItems: "center",
    justifyContent: "center",
    backgroundColor: "#F4F4F6",
    marginTop: 6
  },
  sheetCancelText: {
    color: "#0A0A0B",
    fontSize: 15,
    fontWeight: "900"
  }
});
