import { ScrollView, Text, View } from "react-native";

import { Button } from "@/components/ui/Button";
import { Input } from "@/components/ui/Input";
import { Screen } from "@/components/ui/Screen";
import { useAppTheme } from "@/theme/useAppTheme";

export function ListingScreen() {
  const { colors } = useAppTheme();

  return (
    <Screen>
      <ScrollView showsVerticalScrollIndicator={false} contentContainerStyle={{ paddingTop: 22, paddingBottom: 32, gap: 18 }}>
        <View style={{ gap: 8 }}>
          <Text style={{ color: colors.text, fontSize: 32, lineHeight: 38, fontWeight: "800" }}>List your space</Text>
          <Text style={{ color: colors.muted, fontSize: 16, lineHeight: 23 }}>
            Turn an idle bay, driveway, or office slot into monthly income.
          </Text>
        </View>
        <Input label="Parking title" placeholder="Anna Nagar covered bay" />
        <Input label="Address" placeholder="Street, landmark, locality" />
        <Input label="Locality" placeholder="Anna Nagar" />
        <View style={{ flexDirection: "row", gap: 12 }}>
          <View style={{ flex: 1 }}>
            <Input label="Hourly price" placeholder="80" keyboardType="number-pad" />
          </View>
          <View style={{ flex: 1 }}>
            <Input label="Slots" placeholder="1" keyboardType="number-pad" />
          </View>
        </View>
        <View style={{ borderRadius: 8, backgroundColor: colors.surface, borderWidth: 1, borderColor: colors.border, padding: 16, gap: 12 }}>
          <Text style={{ color: colors.text, fontSize: 18, fontWeight: "800" }}>Availability</Text>
          <Text style={{ color: colors.muted, fontSize: 14, lineHeight: 20 }}>
            Weekdays, 8:00 AM to 10:00 PM
          </Text>
        </View>
        <Button label="Preview listing" />
      </ScrollView>
    </Screen>
  );
}
