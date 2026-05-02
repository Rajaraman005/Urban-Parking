import "react-native-gesture-handler";

import { RootNavigator } from "@/core/navigation/RootNavigator";
import { AppProvider } from "@/core/providers/AppProvider";

export default function App() {
  return (
    <AppProvider>
      <RootNavigator />
    </AppProvider>
  );
}
