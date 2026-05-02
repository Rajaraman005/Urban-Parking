import { SelectField } from "@/features/userSetup/components/SelectField";
import { timeSlotOptions } from "@/features/userSetup/utils/availability";

interface TimeSlotSelectProps {
  label: string;
  value: number;
  onChange: (value: number) => void;
}

export function TimeSlotSelect({ label, onChange, value }: TimeSlotSelectProps) {
  return (
    <SelectField
      label={label}
      menuMaxHeight={240}
      options={timeSlotOptions}
      value={String(value)}
      onChange={(nextValue) => onChange(Number(nextValue))}
    />
  );
}
