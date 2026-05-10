import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_screen.dart';
import '../domain/notification_models.dart';
import 'notification_controller.dart';

class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(notificationsProvider);

    return AppScreen(
      padded: false,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0B0B0C),
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0),
        ),
        actions: [
          TextButton(
            onPressed: () => ref
                .read(notificationReadControllerProvider.notifier)
                .markAllRead(),
            child: const Text('Mark read'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      backgroundColor: const Color(0xFFF7F8FA),
      child: feed.when(
        data: (page) => RefreshIndicator(
          onRefresh: () async => ref.refresh(notificationsProvider.future),
          child: page.items.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 160),
                    _EmptyNotificationState(),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                  itemCount: page.items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final notification = page.items[index];
                    return _NotificationTile(notification: notification);
                  },
                ),
        ),
        error: (error, stackTrace) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 120, 20, 24),
          children: [
            const Icon(Icons.notifications_off_outlined, size: 40),
            const SizedBox(height: 14),
            Text(
              'Notifications are unavailable',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: FilledButton(
                onPressed: () => ref.invalidate(notificationsProvider),
                child: const Text('Retry'),
              ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUnread = notification.isUnread;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () async {
          if (isUnread) {
            await ref
                .read(notificationReadControllerProvider.notifier)
                .markRead(notification.id);
          }
          final deeplink = notification.deeplink;
          if (context.mounted &&
              deeplink != null &&
              deeplink.isNotEmpty &&
              deeplink != '/notifications') {
            context.push(deeplink);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NotificationCategoryIcon(category: notification.category),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: const Color(0xFF101113),
                                  fontWeight: isUnread
                                      ? FontWeight.w900
                                      : FontWeight.w700,
                                  letterSpacing: 0,
                                ),
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: 8),
                          const _UnreadDot(),
                        ],
                      ],
                    ),
                    if (notification.body.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        notification.body,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF5D626B),
                          height: 1.3,
                          letterSpacing: 0,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      _relativeTime(notification.createdAt),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF8B929D),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationCategoryIcon extends StatelessWidget {
  const _NotificationCategoryIcon({required this.category});

  final NotificationCategory category;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (category) {
      NotificationCategory.message => (
        Icons.chat_bubble_outline,
        const Color(0xFF2563EB),
      ),
      NotificationCategory.booking => (
        Icons.calendar_month_outlined,
        const Color(0xFF059669),
      ),
      NotificationCategory.payment => (
        Icons.payments_outlined,
        const Color(0xFF7C3AED),
      ),
      NotificationCategory.security => (
        Icons.shield_outlined,
        const Color(0xFFDC2626),
      ),
      NotificationCategory.admin => (
        Icons.campaign_outlined,
        const Color(0xFFEA580C),
      ),
      NotificationCategory.system => (
        Icons.info_outline,
        const Color(0xFF475569),
      ),
      NotificationCategory.marketing => (
        Icons.local_offer_outlined,
        const Color(0xFFDB2777),
      ),
    };

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: const BoxDecoration(
        color: Color(0xFFE11D48),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _EmptyNotificationState extends StatelessWidget {
  const _EmptyNotificationState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.notifications_none, size: 32),
        ),
        const SizedBox(height: 16),
        Text(
          'No notifications yet',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

String _relativeTime(DateTime value) {
  final now = DateTime.now();
  final diff = now.difference(value.toLocal());
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${value.day}/${value.month}/${value.year}';
}
