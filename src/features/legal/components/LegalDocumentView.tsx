import { Ionicons } from "@expo/vector-icons";
import { Pressable, ScrollView, Text, View } from "react-native";
import { useSafeAreaInsets } from "react-native-safe-area-context";

import type { LegalDocument } from "@/features/legal/data/legalDocuments";
import { useAppTheme } from "@/theme/useAppTheme";

interface LegalDocumentViewProps {
  document: LegalDocument;
  onBack: () => void;
}

export function LegalDocumentView({ document, onBack }: LegalDocumentViewProps) {
  const { colors } = useAppTheme();
  const insets = useSafeAreaInsets();

  return (
    <View style={{ flex: 1, backgroundColor: colors.background }}>
      <View
        style={{
          paddingTop: Math.max(insets.top + 12, 24),
          paddingHorizontal: 20,
          paddingBottom: 12,
          borderBottomWidth: 1,
          borderBottomColor: colors.border,
          backgroundColor: colors.background
        }}
      >
        <Pressable
          accessibilityLabel="Go back"
          accessibilityRole="button"
          onPress={onBack}
          style={{
            width: 42,
            height: 42,
            borderRadius: 21,
            alignItems: "center",
            justifyContent: "center",
            backgroundColor: colors.surface,
            borderWidth: 1,
            borderColor: colors.border
          }}
        >
          <Ionicons name="chevron-back" size={22} color={colors.text} />
        </Pressable>
      </View>
      <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={{ padding: 20, paddingBottom: 42 }}>
        <View style={{ gap: 10, marginBottom: 18 }}>
          <Text style={{ color: colors.text, fontSize: 34, fontWeight: "900", lineHeight: 40 }}>
            {document.title}
          </Text>
          <Text style={{ color: colors.muted, fontSize: 15, fontWeight: "600", lineHeight: 22 }}>
            {document.subtitle}
          </Text>
          <Text style={{ color: colors.text, fontSize: 13, fontWeight: "800" }}>{document.effectiveDate}</Text>
        </View>
        <View
          style={{
            borderRadius: 8,
            borderWidth: 1,
            borderColor: colors.border,
            backgroundColor: colors.surface,
            padding: 14,
            marginBottom: 18
          }}
        >
          <Text style={{ color: colors.muted, fontSize: 13, fontWeight: "600", lineHeight: 20 }}>
            {document.reviewNote}
          </Text>
        </View>
        <View style={{ gap: 14 }}>
          {document.sections.map((section) => (
            <View
              key={section.title}
              style={{
                borderRadius: 8,
                borderWidth: 1,
                borderColor: colors.border,
                backgroundColor: colors.surface,
                padding: 16,
                gap: 10
              }}
            >
              <Text style={{ color: colors.text, fontSize: 18, fontWeight: "900", lineHeight: 24 }}>
                {section.title}
              </Text>
              {section.body.map((paragraph) => (
                <Text key={paragraph} style={{ color: colors.muted, fontSize: 14, fontWeight: "600", lineHeight: 21 }}>
                  {paragraph}
                </Text>
              ))}
            </View>
          ))}
        </View>
      </ScrollView>
    </View>
  );
}
