import { TabPlaceholderScreen } from "@/components/navigation/TabPlaceholderScreen";

export function ProfileScreen() {
  return (
    <TabPlaceholderScreen
      footerBody="Profile is prepared for account settings, host tools, payout details, and the parts of the app users expect to revisit often."
      footerTitle="Account essentials live here"
      highlights={["Account", "Hosting", "Payouts"]}
      icon="person-outline"
      sectionLabel="Profile"
      subtitle="A clean account home for personal settings, hosting context, and everything that belongs to the user rather than the trip."
      title="One place for your account and hosting tools"
    />
  );
}
