import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../config/app_providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/messaging_outbox_store.dart';
import '../data/messaging_repository_impl.dart';
import '../domain/messaging_models.dart';
import '../domain/messaging_repository.dart';

final messagingRepositoryProvider = Provider<MessagingRepository>((ref) {
  return MessagingRepositoryImpl(apiClient: ref.watch(apiClientProvider));
});

final messagingOutboxStoreProvider = Provider<MessagingOutboxStore>((ref) {
  return MessagingOutboxStore();
});

final conversationsProvider = FutureProvider<List<MessagingConversation>>((
  ref,
) {
  return ref.watch(messagingRepositoryProvider).listConversations();
});

final messagesProvider = FutureProvider.family<List<MessagingMessage>, String>((
  ref,
  conversationId,
) async {
  final messages = await ref
      .watch(messagingRepositoryProvider)
      .listMessages(conversationId);
  final latestSeq = messages.isEmpty
      ? null
      : messages
            .map((message) => message.messageSeq)
            .fold<int>(0, (left, right) => right > left ? right : left);
  if (latestSeq != null && latestSeq > 0) {
    scheduleMicrotask(() {
      ref
          .read(messagingReadControllerProvider.notifier)
          .markRead(conversationId, latestSeq);
    });
  }
  return messages;
});

final startPropertyConversationControllerProvider =
    AsyncNotifierProvider<StartPropertyConversationController, void>(
      StartPropertyConversationController.new,
    );

class StartPropertyConversationController extends AsyncNotifier<void> {
  late final MessagingRepository _repository;

  @override
  void build() {
    _repository = ref.watch(messagingRepositoryProvider);
  }

  Future<MessagingConversation> start(String propertyId) async {
    state = const AsyncLoading();
    try {
      final conversation = await _repository.startPropertyConversation(
        propertyId,
      );
      state = const AsyncData(null);
      ref.invalidate(conversationsProvider);
      return conversation;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}

final messageSendControllerProvider =
    NotifierProvider.family<
      MessageSendController,
      AsyncValue<List<MessagingMessage>>,
      String
    >(MessageSendController.new);

class MessageSendController
    extends Notifier<AsyncValue<List<MessagingMessage>>> {
  static const _uuid = Uuid();

  MessageSendController(this._conversationId);

  final String _conversationId;

  @override
  AsyncValue<List<MessagingMessage>> build() {
    unawaited(_loadFailedOutbox());
    return const AsyncData([]);
  }

  Future<void> _loadFailedOutbox() async {
    final outbox = ref.read(messagingOutboxStoreProvider);
    final auth = ref.read(authControllerProvider).value;
    final userId = auth?.user?.id ?? '';
    final pending = await outbox.entriesFor(_conversationId);
    state = AsyncData(
      pending
          .map(
            (entry) => MessagingMessage.pendingText(
              body: entry.body,
              clientMessageId: entry.clientMessageId,
              conversationId: _conversationId,
              senderId: userId,
            ).copyWith(localStatus: LocalMessageStatus.failed),
          )
          .toList(growable: false),
    );
  }

  Future<void> sendText(String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;

    final repository = ref.read(messagingRepositoryProvider);
    final outbox = ref.read(messagingOutboxStoreProvider);
    final auth = ref.read(authControllerProvider).value;
    final userId = auth?.user?.id ?? '';
    final clientMessageId = _uuid.v4();
    final pending = MessagingMessage.pendingText(
      body: trimmed,
      clientMessageId: clientMessageId,
      conversationId: _conversationId,
      senderId: userId,
    );
    state = AsyncData([
      ...(state.value ?? const <MessagingMessage>[]),
      pending,
    ]);

    await outbox.upsert(
      MessagingOutboxEntry(
        clientMessageId: clientMessageId,
        conversationId: _conversationId,
        body: trimmed,
        createdAt: DateTime.now(),
      ),
    );

    try {
      await repository.sendMessage(
        _conversationId,
        SendMessageRequest(body: trimmed, clientMessageId: clientMessageId),
      );
      await outbox.remove(
        conversationId: _conversationId,
        clientMessageId: clientMessageId,
      );
      _removeLocal(clientMessageId);
      ref.invalidate(messagesProvider(_conversationId));
      ref.invalidate(conversationsProvider);
    } catch (error) {
      state = AsyncData([
        for (final message in state.value ?? const <MessagingMessage>[])
          message.clientMessageId == clientMessageId
              ? message.copyWith(localStatus: LocalMessageStatus.failed)
              : message,
      ]);
      rethrow;
    }
  }

  void _removeLocal(String clientMessageId) {
    state = AsyncData([
      for (final message in state.value ?? const <MessagingMessage>[])
        if (message.clientMessageId != clientMessageId) message,
    ]);
  }
}

final messagingReadControllerProvider =
    NotifierProvider<MessagingReadController, Map<String, int>>(
      MessagingReadController.new,
    );

class MessagingReadController extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => const {};

  Future<void> markRead(String conversationId, int messageSeq) async {
    final previous = state[conversationId] ?? 0;
    if (messageSeq <= previous) return;
    state = {...state, conversationId: messageSeq};
    try {
      await ref
          .read(messagingRepositoryProvider)
          .markRead(conversationId, lastSeenMessageSeq: messageSeq);
      ref.invalidate(conversationsProvider);
    } catch (_) {
      // Read receipts are eventually consistent; the next thread refresh retries.
    }
  }
}
