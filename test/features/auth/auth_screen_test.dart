import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:urban_parking/features/auth/domain/auth_repository.dart';
import 'package:urban_parking/features/auth/domain/auth_state.dart';
import 'package:urban_parking/features/auth/presentation/auth_controller.dart';
import 'package:urban_parking/features/auth/presentation/auth_screen.dart';

void main() {
  testWidgets('login form advertises saved credential autofill hints', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(initialMode: 'login'));
    await tester.pumpAndSettle();

    final fields = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .toList();

    expect(fields, hasLength(2));
    expect(fields[0].autofillHints, contains(AutofillHints.username));
    expect(fields[0].autofillHints, contains(AutofillHints.email));
    expect(fields[0].autocorrect, isFalse);
    expect(fields[1].autofillHints, contains(AutofillHints.password));
    expect(fields[1].enableSuggestions, isFalse);
    expect(fields[1].autocorrect, isFalse);
  });

  testWidgets('signup form advertises new password autofill hints', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(initialMode: 'signup'));
    await tester.pumpAndSettle();

    final fields = tester
        .widgetList<EditableText>(find.byType(EditableText))
        .toList();

    expect(fields, hasLength(3));
    expect(fields[0].autofillHints, contains(AutofillHints.name));
    expect(fields[1].autofillHints, contains(AutofillHints.username));
    expect(fields[1].autofillHints, contains(AutofillHints.email));
    expect(fields[2].autofillHints, contains(AutofillHints.newPassword));
  });
}

Widget _harness({required String initialMode}) {
  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(_FakeAuthRepository()),
    ],
    child: MaterialApp(home: AuthScreen(initialMode: initialMode)),
  );
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<AuthState> hydrate() async {
    return const AuthState(status: AuthStatus.unauthenticated);
  }

  @override
  Future<AuthState> refreshSessionOrLogout() => hydrate();

  @override
  Future<void> requestSignupOtp() async {}

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<AuthState> signInWithEmailPassword({
    required String email,
    required String password,
  }) => hydrate();

  @override
  Future<AuthState> signInWithGoogle() => hydrate();

  @override
  Future<void> signOut() async {}

  @override
  Future<AuthState> signUpWithEmailPassword({
    required String fullName,
    required String email,
    required String password,
  }) => hydrate();

  @override
  Future<void> updatePassword(String password) async {}

  @override
  Future<void> verifySignupOtp({required String token}) async {}
}
