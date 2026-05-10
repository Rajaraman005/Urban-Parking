import 'package:flutter_test/flutter_test.dart';
import 'package:urban_parking/features/notifications/domain/notification_models.dart';

void main() {
  test('notification feed page maps canonical API payload', () {
    final page = NotificationFeedPage.fromJson({
      'items': [
        {
          'id': 'notification-1',
          'cursor': '2026-05-10 10:00:00+00|notification-1',
          'category': 'booking',
          'priority': 'high',
          'title': 'New booking request',
          'body': 'A renter requested your parking spot.',
          'deeplink': '/profile/booking-requests',
          'status': 'unread',
          'createdAt': '2026-05-10T10:00:00.000Z',
          'payload': {'bookingId': 'booking-1'},
        },
      ],
      'unreadByCategory': {'all': 3, 'booking': 1},
    });

    expect(page.items, hasLength(1));
    expect(page.items.single.category, NotificationCategory.booking);
    expect(page.items.single.priority, NotificationPriority.high);
    expect(page.items.single.isUnread, isTrue);
    expect(page.items.single.payload['bookingId'], 'booking-1');
    expect(page.totalUnread, 3);
    expect(page.nextCursor, '2026-05-10 10:00:00+00|notification-1');
  });

  test('notification preference update omits null fields', () {
    final update = NotificationPreferenceUpdate(
      category: NotificationCategory.message,
      pushEnabled: false,
    );

    expect(update.toJson(), {'category': 'message', 'pushEnabled': false});
  });
}
