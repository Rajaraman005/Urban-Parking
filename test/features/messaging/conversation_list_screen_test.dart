import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:urban_parking/features/messaging/domain/messaging_models.dart';
import 'package:urban_parking/features/messaging/presentation/conversation_list_screen.dart';
import 'package:urban_parking/features/messaging/presentation/messaging_controller.dart';
import 'package:urban_parking/features/messaging/presentation/messaging_realtime.dart';
import 'package:urban_parking/shared/theme/app_theme.dart';

void main() {
  testWidgets('message inbox renders a clean header and flat rows', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          messagingInboxLiveSyncProvider.overrideWith((ref) {}),
          conversationsProvider.overrideWith((ref) async {
            return [
              _conversation(
                id: 'raja',
                name: 'Raja',
                preview: 'hi',
                propertyTitle: 'Car parking',
                unreadCount: 1,
              ),
              _conversation(
                id: 'unknown',
                name: null,
                preview: 'Is this apartment still available?',
                propertyTitle: 'Covered bay',
              ),
            ];
          }),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: const ConversationListScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Messages'), findsOneWidget);
    expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byIcon(Icons.filter_alt_outlined), findsNothing);
    expect(find.text('All'), findsNothing);
    expect(find.text('Contacts'), findsNothing);
    expect(find.text('Unknown'), findsNothing);
    expect(find.text('New'), findsNothing);
    expect(find.text('Raja'), findsOneWidget);
    expect(find.text('Car parking - hi'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Raja');
    await tester.pumpAndSettle();

    expect(find.text('Car parking - hi'), findsOneWidget);
    expect(find.text('Lotzi member'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

MessagingConversation _conversation({
  required String id,
  required String? name,
  required String preview,
  required String propertyTitle,
  int unreadCount = 0,
}) {
  return MessagingConversation(
    id: id,
    type: MessagingConversationType.property,
    status: 'active',
    unreadCount: unreadCount,
    updatedAt: DateTime(2026, 5, 10, 1),
    lastMessageAt: DateTime(2026, 5, 10, 1),
    lastMessagePreview: preview,
    otherName: name,
    propertyTitle: propertyTitle,
  );
}
