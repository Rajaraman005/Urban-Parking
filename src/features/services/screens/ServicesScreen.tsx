import { TabPlaceholderScreen } from "@/components/navigation/TabPlaceholderScreen";

export function ServicesScreen() {
  return (
    <TabPlaceholderScreen
      footerBody="This tab is reserved for add-on services like support, access help, and value-added experiences around every booking."
      footerTitle="A place for service tools"
      highlights={["Support", "Access help", "Add-ons"]}
      icon="grid-outline"
      sectionLabel="Services"
      subtitle="Keep secondary tools together in one place so the core booking flow stays focused and quiet."
      title="Useful services, kept close"
    />
  );
}
