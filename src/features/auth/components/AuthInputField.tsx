import { Ionicons } from "@expo/vector-icons";
import { forwardRef, useCallback, useEffect, useRef, useState } from "react";
import {
  Animated,
  Easing,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
  type TextInputProps
} from "react-native";

interface AuthInputFieldProps extends TextInputProps {
  error?: string;
  label: string;
}

const MASK_CHARACTER = "\u2022";
const PASSWORD_REVEAL_HOLD_MS = 420;
const PASSWORD_REVEAL_FADE_MS = 170;

type RevealedPasswordCharacter = {
  char: string;
  id: string;
  index: number;
  opacity: Animated.Value;
};

export const AuthInputField = forwardRef<TextInput, AuthInputFieldProps>(function AuthInputField(
  {
    error,
    label,
    onBlur,
    onFocus,
    style,
    value,
    ...props
  },
  ref,
) {
  const isPassword = Boolean(props.secureTextEntry);
  const [isFocused, setIsFocused] = useState(false);
  const [isPasswordHidden, setIsPasswordHidden] = useState(isPassword);
  const [revealedCharacters, setRevealedCharacters] = useState<RevealedPasswordCharacter[]>([]);
  const rawValue = typeof value === "string" ? value : "";
  const shouldUseCustomPasswordMask = isPassword && isPasswordHidden;
  const previousValue = useRef(rawValue);
  const revealedCharactersRef = useRef<RevealedPasswordCharacter[]>([]);
  const revealTimers = useRef<Record<string, ReturnType<typeof setTimeout>>>({});

  useEffect(() => {
    revealedCharactersRef.current = revealedCharacters;
  }, [revealedCharacters]);

  const clearReveal = useCallback(() => {
    Object.values(revealTimers.current).forEach(clearTimeout);
    revealTimers.current = {};
    revealedCharactersRef.current.forEach((item) => item.opacity.stopAnimation());
    setRevealedCharacters([]);
  }, []);

  const scheduleRevealFade = useCallback((item: RevealedPasswordCharacter) => {
    revealTimers.current[item.id] = setTimeout(() => {
      Animated.timing(item.opacity, {
        toValue: 0,
        duration: PASSWORD_REVEAL_FADE_MS,
        easing: Easing.out(Easing.cubic),
        useNativeDriver: true
      }).start(({ finished }) => {
        delete revealTimers.current[item.id];

        if (finished) {
          setRevealedCharacters((current) => current.filter((visibleItem) => visibleItem.id !== item.id));
        }
      });
    }, PASSWORD_REVEAL_HOLD_MS);
  }, []);

  useEffect(
    () => () => {
      Object.values(revealTimers.current).forEach(clearTimeout);
      revealedCharactersRef.current.forEach((item) => item.opacity.stopAnimation());
    },
    []
  );

  useEffect(() => {
    if (!shouldUseCustomPasswordMask) {
      previousValue.current = rawValue;
      clearReveal();
      return;
    }

    const previous = previousValue.current;
    const nextCharacters = Array.from(rawValue);
    const didAppendAtEnd = rawValue.length === previous.length + 1 && rawValue.startsWith(previous);

    if (didAppendAtEnd && nextCharacters.length > 0) {
      const index = nextCharacters.length - 1;
      const item: RevealedPasswordCharacter = {
        char: nextCharacters[index] ?? "",
        id: `${Date.now()}-${index}-${nextCharacters[index] ?? ""}`,
        index,
        opacity: new Animated.Value(1)
      };

      setRevealedCharacters((current) => [
        ...current.filter((visibleItem) => visibleItem.index !== index),
        item
      ]);
      scheduleRevealFade(item);
    } else {
      clearReveal();
    }

    previousValue.current = rawValue;
  }, [clearReveal, rawValue, scheduleRevealFade, shouldUseCustomPasswordMask]);

  const handleFocus: NonNullable<TextInputProps["onFocus"]> = (event) => {
    setIsFocused(true);
    onFocus?.(event);
  };

  const handleBlur: NonNullable<TextInputProps["onBlur"]> = (event) => {
    setIsFocused(false);
    onBlur?.(event);
  };

  const togglePasswordVisibility = () => {
    clearReveal();
    previousValue.current = rawValue;
    setIsPasswordHidden((current) => !current);
  };

  return (
    <View style={styles.container}>
      <Text style={styles.label}>{label}</Text>
      <View style={[styles.inputShell, error ? styles.inputError : null]}>
        <TextInput
          {...props}
          ref={ref}
          autoCapitalize="none"
          autoComplete="off"
          autoCorrect={false}
          caretHidden={shouldUseCustomPasswordMask ? true : props.caretHidden}
          contextMenuHidden={shouldUseCustomPasswordMask ? true : props.contextMenuHidden}
          cursorColor="#111111"
          importantForAutofill="no"
          onBlur={handleBlur}
          onFocus={handleFocus}
          placeholderTextColor="#9A9A9A"
          selection={
            shouldUseCustomPasswordMask && isFocused
              ? { start: rawValue.length, end: rawValue.length }
              : props.selection
          }
          selectionColor="#111111"
          secureTextEntry={isPassword ? false : props.secureTextEntry}
          showSoftInputOnFocus={props.showSoftInputOnFocus ?? true}
          style={[
            styles.input,
            isPassword ? styles.passwordInput : null,
            style,
            shouldUseCustomPasswordMask ? styles.invisiblePasswordInput : null
          ]}
          underlineColorAndroid="transparent"
          value={value}
        />

        {shouldUseCustomPasswordMask ? (
          <View pointerEvents="none" style={styles.passwordOverlay}>
            {rawValue.length === 0 ? (
              <Text style={styles.placeholder}>{props.placeholder}</Text>
            ) : (
              <View style={styles.passwordMaskRow}>
                {Array.from(rawValue).map((character, index) => {
                  const revealedCharacter = revealedCharacters.find((item) => item.index === index);
                  const hiddenBulletOpacity =
                    revealedCharacter
                      ? revealedCharacter.opacity.interpolate({
                          inputRange: [0, 1],
                          outputRange: [1, 0]
                        })
                      : undefined;

                  return (
                    <View key={`${index}-${character}`} style={styles.passwordMaskCell}>
                      {revealedCharacter ? (
                        <Animated.Text style={[styles.passwordMaskText, { opacity: hiddenBulletOpacity }]}>
                          {MASK_CHARACTER}
                        </Animated.Text>
                      ) : (
                        <Text style={styles.passwordMaskText}>{MASK_CHARACTER}</Text>
                      )}
                      {revealedCharacter ? (
                        <Animated.Text style={[styles.passwordRevealText, { opacity: revealedCharacter.opacity }]}>
                          {revealedCharacter.char}
                        </Animated.Text>
                      ) : null}
                    </View>
                  );
                })}
                {isFocused ? <View style={styles.fakeCaret} /> : null}
              </View>
            )}
          </View>
        ) : null}

        {isPassword ? (
          <Pressable
            accessibilityLabel={isPasswordHidden ? "Show password" : "Hide password"}
            accessibilityRole="button"
            hitSlop={10}
            style={styles.eyeButton}
            onPress={togglePasswordVisibility}
          >
            <Ionicons name={isPasswordHidden ? "eye-outline" : "eye-off-outline"} size={20} color="#6E6E6E" />
          </Pressable>
        ) : null}
      </View>
      {error ? <Text style={styles.error}>{error}</Text> : null}
    </View>
  );
});

const styles = StyleSheet.create({
  container: {
    gap: 8
  },
  label: {
    color: "#111111",
    fontSize: 12,
    fontWeight: "800"
  },
  inputShell: {
    height: 52,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: "#E6E6E6",
    backgroundColor: "#FFFFFF",
    overflow: "hidden",
    justifyContent: "center"
  },
  input: {
    height: "100%",
    backgroundColor: "#FFFFFF",
    color: "#111111",
    fontSize: 15,
    fontWeight: "600",
    paddingHorizontal: 14
  },
  invisiblePasswordInput: {
    opacity: 0
  },
  passwordInput: {
    paddingRight: 48
  },
  passwordOverlay: {
    position: "absolute",
    left: 14,
    right: 48,
    height: 52,
    justifyContent: "center",
    overflow: "hidden"
  },
  passwordMaskRow: {
    flexDirection: "row",
    alignItems: "center",
    overflow: "hidden"
  },
  passwordMaskCell: {
    width: 11,
    height: 22,
    alignItems: "center",
    justifyContent: "center"
  },
  passwordMaskText: {
    color: "#111111",
    fontSize: 15,
    fontWeight: "600"
  },
  passwordRevealText: {
    position: "absolute",
    color: "#111111",
    fontSize: 15,
    fontWeight: "600"
  },
  fakeCaret: {
    width: 1.5,
    height: 22,
    marginLeft: 2,
    borderRadius: 1,
    backgroundColor: "#111111"
  },
  placeholder: {
    color: "#9A9A9A",
    fontSize: 15,
    fontWeight: "600"
  },
  eyeButton: {
    position: "absolute",
    right: 4,
    width: 44,
    height: 44,
    alignItems: "center",
    justifyContent: "center"
  },
  inputError: {
    borderColor: "#B42318"
  },
  error: {
    color: "#B42318",
    fontSize: 11,
    fontWeight: "700"
  }
});
