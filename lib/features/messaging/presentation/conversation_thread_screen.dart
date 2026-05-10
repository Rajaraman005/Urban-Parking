import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/errors/app_failure.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/state_view.dart';
import '../domain/messaging_models.dart';
import 'messaging_controller.dart';
import 'messaging_realtime.dart';

class ConversationThreadScreen extends ConsumerStatefulWidget {
  const ConversationThreadScreen({required this.conversationId, super.key});

  final String conversationId;

  @override
  ConsumerState<ConversationThreadScreen> createState() =>
      _ConversationThreadScreenState();
}

class _ConversationThreadScreenState
    extends ConsumerState<ConversationThreadScreen> {
  final _composerController = TextEditingController();

  @override
  void dispose() {
    _composerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(messagingThreadLiveSyncProvider(widget.conversationId));
    final messages = ref.watch(messagesProvider(widget.conversationId));
    final localMessages = ref.watch(
      messageSendControllerProvider(widget.conversationId),
    );
    final conversation = _conversationFrom(ref);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: _ThreadTopBar(
              conversation: conversation,
              onBack: _handleBack,
            ),
          ),
          Expanded(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Color(0xFFF5F6F8),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: messages.when(
                loading: () => const StateView(
                  title: 'Loading conversation',
                  body: 'Syncing messages securely.',
                  isLoading: true,
                ),
                error: (error, _) => StateView(
                  title: 'Could not load conversation',
                  body: error.toString(),
                  actionLabel: 'Try again',
                  onAction: () =>
                      ref.invalidate(messagesProvider(widget.conversationId)),
                ),
                data: (serverMessages) {
                  final merged =
                      [
                        ...serverMessages,
                        ...(localMessages.value ?? const <MessagingMessage>[]),
                      ]..sort((left, right) {
                        final seqCompare = left.messageSeq.compareTo(
                          right.messageSeq,
                        );
                        if (seqCompare != 0) return seqCompare;
                        return left.createdAt.compareTo(right.createdAt);
                      });

                  return Column(
                    children: [
                      if (conversation != null)
                        _PropertyContextBanner(conversation: conversation),
                      Expanded(
                        child: merged.isEmpty
                            ? const StateView(
                                title: 'Start the conversation',
                                body:
                                    'Ask about access, availability, or booking details.',
                              )
                            : ListView.builder(
                                reverse: true,
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  14,
                                  16,
                                  16,
                                ),
                                itemCount: merged.length,
                                itemBuilder: (context, index) {
                                  final message =
                                      merged[merged.length - index - 1];
                                  return _MessageBubble(message: message);
                                },
                              ),
                      ),
                      _MessageComposer(
                        controller: _composerController,
                        isSending: localMessages.isLoading,
                        onSend: _send,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  MessagingConversation? _conversationFrom(WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider).value;
    if (conversations == null) return null;
    for (final conversation in conversations) {
      if (conversation.id == widget.conversationId) return conversation;
    }
    return null;
  }

  void _handleBack() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    context.go('/messages');
  }

  Future<void> _send() async {
    final text = _composerController.text;
    if (text.trim().isEmpty) return;
    _composerController.clear();
    try {
      await ref
          .read(messageSendControllerProvider(widget.conversationId).notifier)
          .sendText(text);
    } catch (error) {
      if (!mounted) return;
      AppToast.error(context, _errorMessage(error));
    }
  }

  String _errorMessage(Object error) {
    if (error is AppFailure) return error.message;
    return 'Could not send this message. Please try again.';
  }
}

class _ThreadTopBar extends StatelessWidget {
  const _ThreadTopBar({required this.conversation, required this.onBack});

  final MessagingConversation? conversation;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 16, 16),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  conversation?.displayTitle ?? 'Messages',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _presenceLabel(conversation),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'More',
            onPressed: () => _showThreadActions(context),
            icon: const Icon(Icons.more_horiz_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  String _presenceLabel(MessagingConversation? conversation) {
    if (conversation?.otherPresenceStatus == 'online') return 'Online';
    final seenAt = conversation?.otherLastSeenAt;
    if (seenAt == null) return conversation?.propertyLabel ?? 'Secure chat';
    return 'Last seen ${DateFormat('d MMM, h:mm a').format(seenAt.toLocal())}';
  }

  void _showThreadActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              ListTile(
                leading: Icon(Icons.archive_outlined),
                title: Text('Archive conversation'),
              ),
              ListTile(
                leading: Icon(Icons.report_gmailerrorred_outlined),
                title: Text('Report safety concern'),
              ),
              ListTile(
                leading: Icon(Icons.block_rounded),
                title: Text('Block user'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PropertyContextBanner extends StatelessWidget {
  const _PropertyContextBanner({required this.conversation});

  final MessagingConversation conversation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(
                    Icons.local_parking_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      conversation.propertyLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      conversation.propertyAddress ??
                          conversation.propertyLocality ??
                          'Property details',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF71717A),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1,
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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final MessagingMessage message;

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    final maxBubbleWidth = math.min(
      MediaQuery.sizeOf(context).width * 0.74,
      320,
    );
    final bodyTextStyle = TextStyle(
      color: isMine ? Colors.white : Colors.black,
      fontSize: 14,
      fontWeight: FontWeight.w700,
      height: 1.28,
      letterSpacing: 0,
    );
    final timeTextStyle = TextStyle(
      color: isMine
          ? Colors.white.withValues(alpha: 0.62)
          : const Color(0xFF71717A),
      fontSize: 10.5,
      fontWeight: FontWeight.w800,
      height: 1,
      letterSpacing: 0,
    );
    final textScaler = MediaQuery.textScalerOf(context);
    final bubbleWidth = _bubbleWidthFor(
      context: context,
      bodyTextStyle: bodyTextStyle,
      isMine: isMine,
      maxBubbleWidth: maxBubbleWidth.toDouble(),
      textScaler: textScaler,
      timeTextStyle: timeTextStyle,
    );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: SizedBox(
          width: bubbleWidth,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isMine ? Colors.black : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMine ? 18 : 6),
                bottomRight: Radius.circular(isMine ? 6 : 18),
              ),
              border: isMine
                  ? null
                  : Border.all(color: Colors.black.withValues(alpha: 0.06)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 10, 13, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.attachments.isNotEmpty)
                    for (final attachment in message.attachments) ...[
                      _AttachmentChip(attachment: attachment, isMine: isMine),
                      const SizedBox(height: 8),
                    ],
                  if ((message.body ?? '').trim().isNotEmpty)
                    Text(message.body ?? '', style: bodyTextStyle),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _timeLabel(message.createdAt),
                            style: timeTextStyle,
                          ),
                          if (isMine) ...[
                            const SizedBox(width: 5),
                            Icon(
                              _statusIcon(message),
                              color: Colors.white.withValues(alpha: 0.72),
                              size: 13,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _statusIcon(MessagingMessage message) {
    return switch (message.localStatus) {
      LocalMessageStatus.pending => Icons.schedule_rounded,
      LocalMessageStatus.failed => Icons.error_outline_rounded,
      LocalMessageStatus.sent =>
        message.readByOther ? Icons.done_all_rounded : Icons.done_rounded,
    };
  }

  double _bubbleWidthFor({
    required BuildContext context,
    required TextStyle bodyTextStyle,
    required bool isMine,
    required double maxBubbleWidth,
    required TextScaler textScaler,
    required TextStyle timeTextStyle,
  }) {
    const horizontalPadding = 26.0;
    const statusIconAndGapWidth = 18.0;
    const footerSafetyWidth = 10.0;
    final minBubbleWidth = isMine ? 104.0 : 88.0;
    final maxContentWidth = math.max(0.0, maxBubbleWidth - horizontalPadding);
    final textDirection = Directionality.of(context);
    final body = (message.body ?? '').trim();
    final bodyWidth = body.isEmpty
        ? 0.0
        : _measureTextWidth(
            body,
            bodyTextStyle,
            maxContentWidth,
            textScaler,
            textDirection,
          );
    final timeWidth =
        _measureTextWidth(
          _timeLabel(message.createdAt),
          timeTextStyle,
          maxContentWidth,
          textScaler,
          textDirection,
        ) +
        (isMine ? statusIconAndGapWidth : 0) +
        footerSafetyWidth;
    final attachmentWidth = message.attachments.isEmpty
        ? 0.0
        : math.min(230.0, maxContentWidth);
    final contentWidth = math.max(
      bodyWidth,
      math.max(timeWidth, attachmentWidth),
    );

    return (contentWidth + horizontalPadding).clamp(
      minBubbleWidth,
      maxBubbleWidth,
    );
  }

  double _measureTextWidth(
    String text,
    TextStyle style,
    double maxWidth,
    TextScaler textScaler,
    ui.TextDirection textDirection,
  ) {
    final painter = TextPainter(
      maxLines: null,
      text: TextSpan(text: text, style: style),
      textScaler: textScaler,
      textDirection: textDirection,
    )..layout(maxWidth: maxWidth);
    return painter.width;
  }

  String _timeLabel(DateTime value) {
    return DateFormat('h:mm a').format(value.toLocal());
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({required this.attachment, required this.isMine});

  final MessagingAttachment attachment;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isMine
            ? Colors.white.withValues(alpha: 0.12)
            : const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              attachment.status == MessagingAttachmentStatus.available
                  ? Icons.attach_file_rounded
                  : Icons.hourglass_top_rounded,
              color: isMine ? Colors.white : Colors.black,
              size: 16,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                attachment.status == MessagingAttachmentStatus.available
                    ? attachment.fileName
                    : 'Scanning attachment',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isMine ? Colors.white : Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final Future<void> Function() onSend;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Attach',
                onPressed: () => _showAttachmentPolicy(context),
                icon: const Icon(Icons.add_rounded),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: 'Message',
                    filled: true,
                    fillColor: const Color(0xFFF4F4F5),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: isSending ? Colors.black45 : Colors.black,
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: isSending ? null : () => unawaited(onSend()),
                  child: const SizedBox(
                    width: 46,
                    height: 46,
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAttachmentPolicy(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 6, 20, 22),
          child: Text(
            'Attachments are uploaded privately and become available after safety scanning.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              height: 1.35,
              letterSpacing: 0,
            ),
          ),
        ),
      ),
    );
  }
}
