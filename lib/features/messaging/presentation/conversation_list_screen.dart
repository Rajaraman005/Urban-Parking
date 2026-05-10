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

enum _InboxFilter { all, unread }

class ConversationListScreen extends ConsumerStatefulWidget {
  const ConversationListScreen({super.key});

  @override
  ConsumerState<ConversationListScreen> createState() =>
      _ConversationListScreenState();
}

class _ConversationListScreenState
    extends ConsumerState<ConversationListScreen> {
  final _searchController = TextEditingController();
  _InboxFilter _filter = _InboxFilter.all;
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
      backgroundColor: const Color(0xFFF8F9FC),
      safeAreaBackgroundColor: const Color(0xFFF8F9FC),
      child: RefreshIndicator(
        color: const Color(0xFF0B0B0C),
        backgroundColor: Colors.white,
        onRefresh: () => ref.refresh(conversationsProvider.future),
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _MessagesHeader(
                controller: _searchController,
                filter: _filter,
                onFilterChanged: (filter) => setState(() => _filter = filter),
                onQueryChanged: (value) => setState(() => _query = value),
                unreadCount: conversations.maybeWhen(
                  data: _unreadTotal,
                  orElse: () => 0,
                ),
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
                      body: 'Try a different search or switch back to All.',
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  sliver: SliverToBoxAdapter(
                    child: _ConversationListPanel(
                      conversations: visibleItems,
                      onConversationTap: (conversation) =>
                          context.push('/messages/${conversation.id}'),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  int _unreadTotal(List<MessagingConversation> conversations) {
    return conversations.fold<int>(
      0,
      (total, conversation) => total + conversation.unreadCount,
    );
  }

  List<MessagingConversation> _visibleConversations(
    List<MessagingConversation> conversations,
  ) {
    final normalizedQuery = _query.trim().toLowerCase();
    return conversations
        .where((conversation) {
          if (_filter == _InboxFilter.unread && conversation.unreadCount <= 0) {
            return false;
          }
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
}

class _MessagesHeader extends StatelessWidget {
  const _MessagesHeader({
    required this.controller,
    required this.filter,
    required this.onFilterChanged,
    required this.onQueryChanged,
    required this.unreadCount,
  });

  final TextEditingController controller;
  final _InboxFilter filter;
  final ValueChanged<_InboxFilter> onFilterChanged;
  final ValueChanged<String> onQueryChanged;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Message',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 29,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: 0,
                  ),
                ),
              ),
              _HeaderGlyph(unreadCount: unreadCount),
            ],
          ),
          const SizedBox(height: 22),
          _SearchFilterRow(
            controller: controller,
            onFilterTap: () => onFilterChanged(
              filter == _InboxFilter.unread
                  ? _InboxFilter.all
                  : _InboxFilter.unread,
            ),
            onQueryChanged: onQueryChanged,
          ),
          const SizedBox(height: 14),
          _InboxSegmentedControl(selected: filter, onChanged: onFilterChanged),
        ],
      ),
    );
  }
}

class _HeaderGlyph extends StatelessWidget {
  const _HeaderGlyph({required this.unreadCount});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;
    return SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE8EAF0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.035),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.forum_outlined,
                color: Color(0xFF111827),
                size: 21,
              ),
            ),
          ),
          if (hasUnread)
            Positioned(
              right: -1,
              top: -1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFE11D48),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const SizedBox(width: 12, height: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchFilterRow extends StatelessWidget {
  const _SearchFilterRow({
    required this.controller,
    required this.onFilterTap,
    required this.onQueryChanged,
  });

  final TextEditingController controller;
  final VoidCallback onFilterTap;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE8EAF0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.025),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: TextField(
              controller: controller,
              onChanged: onQueryChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.2,
                letterSpacing: 0,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.fromLTRB(16, 14, 14, 14),
                hintText: 'Search...',
                hintStyle: TextStyle(
                  color: Color(0xFFB4B8C2),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Color(0xFF9CA3AF),
                  size: 22,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onFilterTap,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE8EAF0)),
              ),
              child: const SizedBox(
                width: 54,
                height: 52,
                child: Icon(
                  Icons.filter_list_rounded,
                  color: Color(0xFF111827),
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InboxSegmentedControl extends StatelessWidget {
  const _InboxSegmentedControl({
    required this.onChanged,
    required this.selected,
  });

  final ValueChanged<_InboxFilter> onChanged;
  final _InboxFilter selected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDEFF5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Row(
          children: [
            _InboxSegment(
              isSelected: selected == _InboxFilter.all,
              label: 'All',
              onTap: () => onChanged(_InboxFilter.all),
            ),
            _InboxSegment(
              isSelected: selected == _InboxFilter.unread,
              label: 'Unread',
              onTap: () => onChanged(_InboxFilter.unread),
            ),
          ],
        ),
      ),
    );
  }
}

class _InboxSegment extends StatelessWidget {
  const _InboxSegment({
    required this.isSelected,
    required this.label,
    required this.onTap,
  });

  final bool isSelected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: isSelected ? const Color(0xFFF7F8FB) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 38,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFF111827)
                      : const Color(0xFF9CA3AF),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationListPanel extends StatelessWidget {
  const _ConversationListPanel({
    required this.conversations,
    required this.onConversationTap,
  });

  final List<MessagingConversation> conversations;
  final ValueChanged<MessagingConversation> onConversationTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEDEFF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            for (var index = 0; index < conversations.length; index++) ...[
              _ConversationTile(
                conversation: conversations[index],
                onTap: () => onConversationTap(conversations[index]),
              ),
              if (index != conversations.length - 1)
                const Padding(
                  padding: EdgeInsets.only(left: 82),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFF1F2F6),
                  ),
                ),
            ],
          ],
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
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              _ConversationAvatar(conversation: conversation),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF111827),
                        fontSize: 15.5,
                        fontWeight: isUnread
                            ? FontWeight.w900
                            : FontWeight.w800,
                        height: 1,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _previewLabel(conversation),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isUnread
                            ? const Color(0xFF111827)
                            : const Color(0xFF7B8190),
                        fontSize: 13,
                        fontWeight: isUnread
                            ? FontWeight.w800
                            : FontWeight.w700,
                        height: 1.15,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _timeLabel(conversation.lastMessageAt),
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
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
    return '$property · $preview';
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
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipOval(
          child: SizedBox(
            width: 50,
            height: 50,
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
        ),
        Positioned(
          right: 1,
          bottom: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: conversation.otherPresenceStatus == 'online'
                  ? const Color(0xFF18C964)
                  : const Color(0xFFB4B8C2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.2),
            ),
            child: const SizedBox(width: 12, height: 12),
          ),
        ),
      ],
    );
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEFF3F8), Color(0xFFDCE3EE)],
        ),
      ),
      child: Center(
        child: Text(
          _initials(name),
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 15,
            fontWeight: FontWeight.w900,
            height: 1,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }

  String _initials(String value) {
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
        color: Color(0xFFE11D48),
        shape: BoxShape.circle,
      ),
      child: SizedBox(
        width: 18,
        height: 18,
        child: Center(
          child: Text(
            count > 9 ? '9+' : '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9.5,
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
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFEDEFF5)),
        ),
        child: Column(
          children: const [
            _SkeletonTile(),
            Divider(height: 1, color: Color(0xFFF1F2F6), indent: 82),
            _SkeletonTile(),
            Divider(height: 1, color: Color(0xFFF1F2F6), indent: 82),
            _SkeletonTile(),
          ],
        ),
      ),
    );
  }
}

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          const _SkeletonCircle(),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _SkeletonLine(widthFactor: 0.42, height: 13),
                SizedBox(height: 10),
                _SkeletonLine(widthFactor: 0.78, height: 11),
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
        color: const Color(0xFFEDEFF5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const SizedBox(width: 50, height: 50),
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
          color: const Color(0xFFEDEFF5),
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
