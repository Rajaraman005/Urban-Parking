import { TabPlaceholderScreen } from "@/components/navigation/TabPlaceholderScreen";

export function RentalScreen() {
  return (
    <TabPlaceholderScreen
      footerBody="This tab is ready for renter-first discovery flows like recent bookings, favorites, and repeat parking plans."
      footerTitle="Built for repeat parking"
      highlights={["Daily", "Monthly", "Commute"]}
      icon="car-sport-outline"
      sectionLabel="Rental"
      subtitle="A focused place for renters to manage recurring needs, compare plans, and get back to the right space quickly."
      title="Rental plans that feel easy to manage"
    />
  );
}
