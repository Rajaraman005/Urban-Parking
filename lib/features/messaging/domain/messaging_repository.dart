import 'messaging_models.dart';

abstract interface class MessagingRepository {
  Future<MessagingConversation> startPropertyConversation(String propertyId);

  Future<List<MessagingConversation>> listConversations({
    int limit = 20,
    DateTime? beforeLastMessageAt,
    String? beforeId,
  });

  Future<List<MessagingMessage>> listMessages(
    String conversationId, {
    int limit = 50,
    int? beforeMessageSeq,
  });

  Future<MessagingMessage> sendMessage(
    String conversationId,
    SendMessageRequest request,
  );

  Future<void> markRead(String conversationId, {int? lastSeenMessageSeq});

  Future<void> setTyping(String conversationId, {required bool isTyping});
}
