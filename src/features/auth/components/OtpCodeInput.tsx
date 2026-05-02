import { useEffect, useRef } from "react";
import { Pressable, StyleSheet, Text, TextInput, View } from "react-native";

interface OtpCodeInputProps {
  error?: string;
  autoFocus?: boolean;
  onBlur?: () => void;
  onChangeText: (value: string) => void;
  value: string;
}

const OTP_LENGTH = 6;

const sanitizeOtp = (value: string) => value.replace(/\D/g, "").slice(0, OTP_LENGTH);

export function OtpCodeInput({ autoFocus, error, onBlur, onChangeText, value }: OtpCodeInputProps) {
  const inputRef = useRef<TextInput>(null);
  const code = sanitizeOtp(value);

  useEffect(() => {
    if (!autoFocus) {
      return;
    }

    const frame = requestAnimationFrame(() => {
      inputRef.current?.focus();
    });

    return () => cancelAnimationFrame(frame);
  }, [autoFocus]);

  const focusInput = () => {
    inputRef.current?.focus();
  };

  return (
    <View style={styles.container}>
      <Pressable accessibilityRole="button" style={styles.inputShell} onPress={focusInput}>
        <TextInput
          ref={inputRef}
          autoComplete="one-time-code"
          importantForAutofill="yes"
          keyboardType="number-pad"
          maxLength={OTP_LENGTH}
          onBlur={onBlur}
          onChangeText={(nextValue) => onChangeText(sanitizeOtp(nextValue))}
          onPressIn={focusInput}
          placeholder="------"
          placeholderTextColor="#CFCFCF"
          selectionColor="#0B0B0C"
          showSoftInputOnFocus
          style={[styles.nativeInput, error ? styles.inputError : null]}
          textContentType="oneTimeCode"
          value={code}
        />
      </Pressable>
      {error ? <Text style={styles.error}>{error}</Text> : null}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    gap: 8
  },
  inputShell: {
    minHeight: 58,
    justifyContent: "center",
  },
  nativeInput: {
    width: "100%",
    height: 56,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: "#E7E7E7",
    backgroundColor: "#F6F6F6",
    color: "#0B0B0C",
    fontSize: 23,
    fontWeight: "900",
    letterSpacing: 18,
    paddingLeft: 18,
    paddingRight: 0,
    textAlign: "left",
    textAlignVertical: "center"
  },
  inputError: {
    borderColor: "#B42318",
    backgroundColor: "#FFF5F4"
  },
  error: {
    color: "#B42318",
    fontSize: 11,
    fontWeight: "700"
  }
});
