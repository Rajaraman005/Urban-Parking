import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../shared/widgets/app_screen.dart';
import '../../../shared/widgets/state_view.dart';
import '../domain/messaging_models.dart';
import 'messaging_controller.dart';
import 'messaging_realtime.dart';

class ConversationListScreen extends ConsumerStatefulWidget {
  const ConversationListScreen({super.key});

  @override
  ConsumerState<ConversationListScreen> createState() =>
      _ConversationListScreenState();
}

class _ConversationListScreenState
    extends ConsumerState<ConversationListScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(messagingInboxLiveSyncProvider);
    final conversations = ref.watch(conversationsProvider);

    return AppScreen(
      padded: false,
      backgroundColor: const Color(0xFFF7F7F8),
      safeAreaBackgroundColor: const Color(0xFFF7F7F8),
      child: RefreshIndicator(
        color: const Color(0xFF111111),
        backgroundColor: Colors.white,
        onRefresh: () => ref.refresh(conversationsProvider.future),
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _MessagesHeader(
                controller: _searchController,
                onBack: _handleBack,
                onQueryChanged: (value) => setState(() => _query = value),
              ),
            ),
            conversations.when(
              loading: () =>
                  const SliverToBoxAdapter(child: _ConversationSkeletonList()),
              error: (error, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  child: StateView(
                    title: 'Could not load messages',
                    body: error.toString(),
                    actionLabel: 'Try again',
                    onAction: () => ref.invalidate(conversationsProvider),
                  ),
                ),
              ),
              data: (items) {
                final visibleItems = _visibleConversations(items);
                if (items.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _InboxEmptyState(
                      title: 'No messages yet',
                      body: 'Message a host from a property page to start.',
                    ),
                  );
                }

                if (visibleItems.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _InboxEmptyState(
                      title: 'No conversations found',
                      body: 'Try a different search.',
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 40),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final conversation = visibleItems[index];
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == visibleItems.length - 1 ? 0 : 15,
                        ),
                        child: _ConversationTile(
                          conversation: conversation,
                          onTap: () =>
                              context.push('/messages/${conversation.id}'),
                        ),
                      );
                    }, childCount: visibleItems.length),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<MessagingConversation> _visibleConversations(
    List<MessagingConversation> conversations,
  ) {
    final normalizedQuery = _query.trim().toLowerCase();
    return conversations
        .where((conversation) {
          if (normalizedQuery.isEmpty) return true;
          return _searchableText(conversation).contains(normalizedQuery);
        })
        .toList(growable: false);
  }

  String _searchableText(MessagingConversation conversation) {
    return [
      conversation.displayTitle,
      conversation.propertyLabel,
      conversation.preview,
      conversation.propertyAddress,
      conversation.propertyLocality,
    ].whereType<String>().join(' ').toLowerCase();
  }

  void _handleBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    context.go('/home');
  }
}

class _MessagesHeader extends StatelessWidget {
  const _MessagesHeader({
    required this.controller,
    required this.onBack,
    required this.onQueryChanged,
  });

  final TextEditingController controller;
  final VoidCallback onBack;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 42,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _HeaderIconButton(onTap: onBack),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Messages',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF18181B),
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      height: 1,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _SearchFilterRow(
            controller: controller,
            onQueryChanged: onQueryChanged,
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Icon(
              Icons.arrow_back_rounded,
              color: Color(0xFF171717),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchFilterRow extends StatelessWidget {
  const _SearchFilterRow({
    required this.controller,
    required this.onQueryChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: TextField(
          controller: controller,
          onChanged: onQueryChanged,
          textAlignVertical: TextAlignVertical.center,
          textInputAction: TextInputAction.search,
          style: const TextStyle(
            color: Color(0xFF171717),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.1,
            letterSpacing: 0,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            isDense: true,
            contentPadding: EdgeInsets.fromLTRB(0, 14, 16, 14),
            hintText: 'Search',
            hintStyle: TextStyle(
              color: Color(0xFF8F949D),
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: Color(0xFF8F949D),
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.onTap});

  final MessagingConversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUnread = conversation.unreadCount > 0;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(2, 3, 0, 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ConversationAvatar(conversation: conversation),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF151515),
                        fontSize: 14,
                        fontWeight: isUnread
                            ? FontWeight.w800
                            : FontWeight.w600,
                        height: 1,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _previewLabel(conversation),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isUnread
                            ? const Color(0xFF343434)
                            : const Color(0xFF9A9CA3),
                        fontSize: 11.5,
                        fontWeight: isUnread
                            ? FontWeight.w700
                            : FontWeight.w500,
                        height: 1.15,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _timeLabel(conversation.lastMessageAt),
                      style: const TextStyle(
                        color: Color(0xFF9699A1),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        height: 1,
                        letterSpacing: 0,
                      ),
                    ),
                    if (isUnread) ...[
                      const SizedBox(height: 8),
                      _UnreadBadge(count: conversation.unreadCount),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _previewLabel(MessagingConversation conversation) {
    final property = conversation.propertyLabel.trim();
    final preview = conversation.preview.trim();
    if (preview.isEmpty || preview == 'Start the conversation') {
      return property;
    }
    if (property.isEmpty || property == 'Property conversation') return preview;
    return '$property - $preview';
  }

  String _timeLabel(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final now = DateTime.now();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return DateFormat('h:mm a').format(local);
    }
    return DateFormat('d MMM').format(local);
  }
}

class _ConversationAvatar extends StatelessWidget {
  const _ConversationAvatar({required this.conversation});

  final MessagingConversation conversation;

  @override
  Widget build(BuildContext context) {
    final url = conversation.otherAvatarUrl?.trim();
    return ClipOval(
      child: SizedBox(
        width: 38,
        height: 38,
        child: url == null || url.isEmpty
            ? _InitialAvatar(name: conversation.displayTitle)
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    _InitialAvatar(name: conversation.displayTitle),
                errorWidget: (_, _, _) =>
                    _InitialAvatar(name: conversation.displayTitle),
              ),
      ),
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _avatarColors(name),
        ),
      ),
      child: Center(
        child: Text(
          _initials(name),
          style: const TextStyle(
            color: Color(0xFF171717),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            height: 1,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }

  List<Color> _avatarColors(String value) {
    final bucket = value.codeUnits.fold<int>(0, (total, unit) => total + unit);
    return switch (bucket % 4) {
      0 => const [Color(0xFFE9F5F1), Color(0xFFB8DDD1)],
      1 => const [Color(0xFFF7E8E8), Color(0xFFE6B9B9)],
      2 => const [Color(0xFFE8EEF8), Color(0xFFB7CAE8)],
      _ => const [Color(0xFFFFF1D8), Color(0xFFE6C488)],
    };
  }

  String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    final compact = value
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();
    if (compact.length >= 2) return compact.substring(0, 2);
    if (compact.length == 1) return compact;
    return 'LZ';
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        shape: BoxShape.circle,
      ),
      child: SizedBox(
        width: 15,
        height: 15,
        child: Center(
          child: Text(
            count > 9 ? '9+' : '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              height: 1,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationSkeletonList extends StatelessWidget {
  const _ConversationSkeletonList();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
      child: Column(
        children: const [
          _SkeletonTile(),
          SizedBox(height: 15),
          _SkeletonTile(),
          SizedBox(height: 15),
          _SkeletonTile(),
        ],
      ),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 3, 0, 3),
      child: Row(
        children: [
          const _SkeletonCircle(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _SkeletonLine(widthFactor: 0.34, height: 12),
                SizedBox(height: 9),
                _SkeletonLine(widthFactor: 0.72, height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonCircle extends StatelessWidget {
  const _SkeletonCircle();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE6E7EA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const SizedBox(width: 38, height: 38),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.height, required this.widthFactor});

  final double height;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFE6E7EA),
          borderRadius: BorderRadius.circular(999),
        ),
        child: SizedBox(height: height),
      ),
    );
  }
}

class _InboxEmptyState extends StatelessWidget {
  const _InboxEmptyState({required this.body, required this.title});

  final String body;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 42, 28, 32),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFEDEFF5)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.forum_outlined,
                  color: Color(0xFF111827),
                  size: 30,
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF7B8190),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
