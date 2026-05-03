import { memo } from "react";
import { StyleSheet, useWindowDimensions, View } from "react-native";

import { IconActionButton, type IconActionButtonProps } from "@/components/ui/IconActionButton";

const DEFAULT_SIDE_INSET = 40;
const ITEM_GAP = 10;

export interface IconActionButtonItem extends IconActionButtonProps {
  id: string;
}

interface IconActionButtonRowProps {
  actions: readonly IconActionButtonItem[];
  sideInset?: number;
}

export const IconActionButtonRow = memo(function IconActionButtonRow({
  actions,
  sideInset = DEFAULT_SIDE_INSET,
}: IconActionButtonRowProps) {
  const { width: screenWidth } = useWindowDimensions();
  const itemCount = Math.max(actions.length, 1);
  const availableWidth = Math.max(0, screenWidth - sideInset - ITEM_GAP * (itemCount - 1));
  const buttonWidth = Math.max(82, Math.floor(availableWidth / itemCount));

  return (
    <View style={styles.row}>
      {actions.map((action, index) => (
        <View key={action.id} style={index > 0 ? styles.itemSpacing : null}>
          <IconActionButton
            accessibilityLabel={action.accessibilityLabel}
            icon={action.icon}
            label={action.label}
            width={buttonWidth}
            onPress={action.onPress}
          />
        </View>
      ))}
    </View>
  );
});

const styles = StyleSheet.create({
  row: {
    width: "100%",
    height: 76,
    flexDirection: "row",
    alignItems: "center",
    marginBottom: 4,
  },
  itemSpacing: {
    marginLeft: ITEM_GAP,
  },
});
