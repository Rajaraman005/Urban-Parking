import type { NativeStackScreenProps } from "@react-navigation/native-stack";

import type { RootStackParamList } from "@/core/navigation/types";
import { LegalDocumentView } from "@/features/legal/components/LegalDocumentView";
import { termsOfUse } from "@/features/legal/data/legalDocuments";

type Props = NativeStackScreenProps<RootStackParamList, "TermsOfUse">;

export function TermsOfUseScreen({ navigation }: Props) {
  return <LegalDocumentView document={termsOfUse} onBack={() => navigation.goBack()} />;
}
