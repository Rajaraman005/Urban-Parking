import type { NativeStackScreenProps } from "@react-navigation/native-stack";

import type { RootStackParamList } from "@/core/navigation/types";
import { LegalDocumentView } from "@/features/legal/components/LegalDocumentView";
import { privacyPolicy } from "@/features/legal/data/legalDocuments";

type Props = NativeStackScreenProps<RootStackParamList, "PrivacyPolicy">;

export function PrivacyPolicyScreen({ navigation }: Props) {
  return <LegalDocumentView document={privacyPolicy} onBack={() => navigation.goBack()} />;
}
