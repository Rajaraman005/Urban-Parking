import { Ionicons } from "@expo/vector-icons";
import { type ComponentProps } from "react";
import { ScrollView, StyleSheet, Text, View } from "react-native";

import { Screen } from "@/components/ui/Screen";
import { useAppTheme } from "@/theme/useAppTheme";

type IconName = ComponentProps<typeof Ionicons>["name"];

interface TabPlaceholderScreenProps {
  footerBody: string;
  footerTitle: string;
  highlights: readonly string[];
  icon: IconName;
  sectionLabel: string;
  subtitle: string;
  title: string;
}

export function TabPlaceholderScreen({
  footerBody,
  footerTitle,
  highlights,
  icon,
  sectionLabel,
  subtitle,
  title
}: TabPlaceholderScreenProps) {
  const { colors } = useAppTheme();

  return (
    <Screen>
      <ScrollView contentContainerStyle={styles.content} showsVerticalScrollIndicator={false}>
        <View style={[styles.heroCard, { backgroundColor: colors.surface, borderColor: colors.border }]}>
          <View style={[styles.badge, { backgroundColor: "#F4F4F6" }]}>
            <Ionicons color={colors.text} name={icon} size={20} />
            <Text style={[styles.badgeText, { color: colors.muted }]}>{sectionLabel}</Text>
          </View>
          <Text style={[styles.title, { color: colors.text }]}>{title}</Text>
          <Text style={[styles.subtitle, { color: colors.muted }]}>{subtitle}</Text>
          <View style={styles.highlightRow}>
            {highlights.map((item) => (
              <View key={item} style={styles.highlightChip}>
                <Text style={styles.highlightChipText}>{item}</Text>
              </View>
            ))}
          </View>
        </View>

        <View style={[styles.noteCard, { backgroundColor: colors.surface, borderColor: colors.border }]}>
          <Text style={[styles.noteTitle, { color: colors.text }]}>{footerTitle}</Text>
          <Text style={[styles.noteBody, { color: colors.muted }]}>{footerBody}</Text>
        </View>
      </ScrollView>
    </Screen>
  );
}

const styles = StyleSheet.create({
  content: {
    paddingTop: 20,
    paddingBottom: 32,
    gap: 16
  },
  heroCard: {
    borderRadius: 24,
    borderWidth: 1,
    padding: 20,
    gap: 16
  },
  badge: {
    alignSelf: "flex-start",
    flexDirection: "row",
    alignItems: "center",
    gap: 8,
    borderRadius: 999,
    paddingHorizontal: 12,
    paddingVertical: 8
  },
  badgeText: {
    fontSize: 12,
    fontWeight: "800"
  },
  title: {
    fontSize: 28,
    lineHeight: 34,
    fontWeight: "900"
  },
  subtitle: {
    fontSize: 15,
    lineHeight: 23,
    fontWeight: "600"
  },
  highlightRow: {
    flexDirection: "row",
    flexWrap: "wrap",
    gap: 10
  },
  highlightChip: {
    borderRadius: 999,
    backgroundColor: "#F4F4F6",
    paddingHorizontal: 12,
    paddingVertical: 8
  },
  highlightChipText: {
    color: "#0A0A0B",
    fontSize: 12,
    fontWeight: "800"
  },
  noteCard: {
    borderRadius: 24,
    borderWidth: 1,
    padding: 20,
    gap: 8
  },
  noteTitle: {
    fontSize: 18,
    lineHeight: 24,
    fontWeight: "900"
  },
  noteBody: {
    fontSize: 14,
    lineHeight: 21,
    fontWeight: "600"
  }
});
