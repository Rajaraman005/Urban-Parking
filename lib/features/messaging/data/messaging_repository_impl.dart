import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/errors/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/app_logger.dart';
import '../domain/messaging_models.dart';
import '../domain/messaging_repository.dart';

class MessagingRepositoryImpl implements MessagingRepository {
  const MessagingRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<MessagingConversation> startPropertyConversation(
    String propertyId,
  ) async {
    try {
      final response = await _apiClient.dio.post<Map<String, Object?>>(
        '/conversations/start',
        data: {'propertyId': propertyId},
      );
      return MessagingConversation.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      final failure = ApiClient.toFailure(error);
      if (_shouldUseSupabaseRpcFallback(failure)) {
        _logApiFallback('start_property_conversation', failure);
        return _startPropertyConversationViaSupabase(propertyId);
      }
      throw failure;
    } catch (_) {
      throw const NetworkFailure(
        'Could not open messages. Please try again.',
        code: 'conversation_start_failed',
      );
    }
  }

  @override
  Future<List<MessagingConversation>> listConversations({
    int limit = 20,
    DateTime? beforeLastMessageAt,
    String? beforeId,
  }) async {
    try {
      final queryParameters = <String, Object?>{
        'limit': limit,
        'beforeLastMessageAt': beforeLastMessageAt?.toIso8601String(),
        'beforeId': beforeId,
      }..removeWhere((_, value) => value == null);
      final response = await _apiClient.dio.get<Map<String, Object?>>(
        '/conversations',
        queryParameters: queryParameters,
      );
      final items = response.data?['items'];
      if (items is! List) return const [];
      return items.map(MessagingConversation.fromJson).toList(growable: false);
    } on DioException catch (error) {
      final failure = ApiClient.toFailure(error);
      if (_shouldUseSupabaseRpcFallback(failure)) {
        _logApiFallback('list_conversations', failure);
        return _listConversationsViaSupabase(
          limit: limit,
          beforeLastMessageAt: beforeLastMessageAt,
          beforeId: beforeId,
        );
      }
      throw failure;
    } catch (_) {
      throw const NetworkFailure(
        'Could not load messages. Please try again.',
        code: 'conversation_list_failed',
      );
    }
  }

  @override
  Future<List<MessagingMessage>> listMessages(
    String conversationId, {
    int limit = 50,
    int? beforeMessageSeq,
  }) async {
    try {
      final queryParameters = <String, Object?>{
        'limit': limit,
        'beforeSeq': beforeMessageSeq,
      }..removeWhere((_, value) => value == null);
      final response = await _apiClient.dio.get<Map<String, Object?>>(
        '/conversations/$conversationId/messages',
        queryParameters: queryParameters,
      );
      final items = response.data?['items'];
      if (items is! List) return const [];
      return items.map(MessagingMessage.fromJson).toList(growable: false);
    } on DioException catch (error) {
      final failure = ApiClient.toFailure(error);
      if (_shouldUseSupabaseRpcFallback(failure)) {
        _logApiFallback('list_messages', failure);
        return _listMessagesViaSupabase(
          conversationId,
          limit: limit,
          beforeMessageSeq: beforeMessageSeq,
        );
      }
      throw failure;
    } catch (_) {
      throw const NetworkFailure(
        'Could not load this conversation. Please try again.',
        code: 'message_list_failed',
      );
    }
  }

  @override
  Future<MessagingMessage> sendMessage(
    String conversationId,
    SendMessageRequest request,
  ) async {
    try {
      final response = await _apiClient.dio.post<Map<String, Object?>>(
        '/conversations/$conversationId/messages',
        data: request.toJson(),
      );
      return MessagingMessage.fromJson(response.data ?? const {});
    } on DioException catch (error) {
      final failure = ApiClient.toFailure(error);
      if (_shouldUseSupabaseRpcFallback(failure)) {
        _logApiFallback('send_message', failure);
        return _sendMessageViaSupabase(conversationId, request);
      }
      throw failure;
    } catch (_) {
      throw const NetworkFailure(
        'Could not send this message. Please try again.',
        code: 'message_send_failed',
      );
    }
  }

  @override
  Future<void> markRead(
    String conversationId, {
    int? lastSeenMessageSeq,
  }) async {
    try {
      await _apiClient.dio.post<Map<String, Object?>>(
        '/conversations/$conversationId/read',
        data: {'lastSeenMessageSeq': lastSeenMessageSeq},
      );
    } on DioException catch (error) {
      final failure = ApiClient.toFailure(error);
      if (_shouldUseSupabaseRpcFallback(failure)) {
        _logApiFallback('mark_read', failure);
        await _markReadViaSupabase(
          conversationId,
          lastSeenMessageSeq: lastSeenMessageSeq,
        );
        return;
      }
      throw failure;
    } catch (_) {
      throw const NetworkFailure(
        'Could not update read state.',
        code: 'message_read_failed',
      );
    }
  }

  @override
  Future<void> setTyping(
    String conversationId, {
    required bool isTyping,
  }) async {
    final client = sb.Supabase.instance.client;
    await client.rpc(
      'set_typing_status',
      params: {'p_conversation_id': conversationId, 'p_is_typing': isTyping},
    );
  }

  Future<MessagingConversation> _startPropertyConversationViaSupabase(
    String propertyId,
  ) async {
    try {
      final data = await sb.Supabase.instance.client.rpc(
        'start_or_get_property_conversation',
        params: {'p_property_id': propertyId},
      );
      return MessagingConversation.fromJson(data);
    } on sb.PostgrestException catch (error) {
      throw _messagingSupabaseFailure(
        error,
        fallbackMessage: 'Could not open messages. Please try again.',
      );
    }
  }

  Future<List<MessagingConversation>> _listConversationsViaSupabase({
    required int limit,
    DateTime? beforeLastMessageAt,
    String? beforeId,
  }) async {
    try {
      final data = await sb.Supabase.instance.client.rpc(
        'list_conversations',
        params: {
          'p_limit': limit,
          'p_before_last_message_at': beforeLastMessageAt?.toIso8601String(),
          'p_before_id': beforeId,
        },
      );
      if (data is! List) return const [];
      return data.map(MessagingConversation.fromJson).toList(growable: false);
    } on sb.PostgrestException catch (error) {
      throw _messagingSupabaseFailure(
        error,
        fallbackMessage: 'Could not load messages. Please try again.',
      );
    }
  }

  Future<List<MessagingMessage>> _listMessagesViaSupabase(
    String conversationId, {
    required int limit,
    int? beforeMessageSeq,
  }) async {
    try {
      final data = await sb.Supabase.instance.client.rpc(
        'list_conversation_messages',
        params: {
          'p_conversation_id': conversationId,
          'p_limit': limit,
          'p_before_message_seq': beforeMessageSeq,
        },
      );
      if (data is! List) return const [];
      return data.map(MessagingMessage.fromJson).toList(growable: false);
    } on sb.PostgrestException catch (error) {
      throw _messagingSupabaseFailure(
        error,
        fallbackMessage: 'Could not load this conversation. Please try again.',
      );
    }
  }

  Future<MessagingMessage> _sendMessageViaSupabase(
    String conversationId,
    SendMessageRequest request,
  ) async {
    try {
      final data = await sb.Supabase.instance.client.rpc(
        'send_message',
        params: {
          'p_conversation_id': conversationId,
          'p_client_message_id': request.clientMessageId,
          'p_body': request.body,
          'p_message_type': request.messageType.apiValue,
          'p_metadata': request.metadata,
          'p_reply_to_message_id': null,
        },
      );
      return MessagingMessage.fromJson(data);
    } on sb.PostgrestException catch (error) {
      throw _messagingSupabaseFailure(
        error,
        fallbackMessage: 'Could not send this message. Please try again.',
      );
    }
  }

  Future<void> _markReadViaSupabase(
    String conversationId, {
    int? lastSeenMessageSeq,
  }) async {
    try {
      await sb.Supabase.instance.client.rpc(
        'mark_conversation_read',
        params: {
          'p_conversation_id': conversationId,
          'p_last_seen_message_seq': lastSeenMessageSeq,
        },
      );
    } on sb.PostgrestException catch (error) {
      throw _messagingSupabaseFailure(
        error,
        fallbackMessage: 'Could not update read state.',
      );
    }
  }

  bool _shouldUseSupabaseRpcFallback(AppFailure failure) {
    return failure is ConfigurationFailure &&
        failure.code == 'deployment_misconfiguration';
  }

  void _logApiFallback(String operation, AppFailure failure) {
    appLogger.warn('messaging_mobile_api_fallback_to_supabase_rpc', {
      'operation': operation,
      'failureCode': failure.code,
      'failureType': failure.runtimeType.toString(),
    });
  }

  AppFailure _messagingSupabaseFailure(
    sb.PostgrestException error, {
    required String fallbackMessage,
  }) {
    final code = error.code ?? 'messaging_rpc_failed';
    final message = error.message.trim();
    final lowerMessage = message.toLowerCase();
    appLogger.error('messaging_supabase_rpc_failed', {
      'code': code,
      'message': message,
    });

    if (code == '42883' ||
        (lowerMessage.contains('function') &&
            lowerMessage.contains('does not exist'))) {
      return const ConfigurationFailure(
        'Messaging database migration is not installed yet.',
        code: 'messaging_schema_missing',
        retryable: false,
      );
    }

    if (code == '42501') {
      return AuthFailure(
        message.isEmpty ? 'Sign in before using messages.' : message,
        code: 'messaging_forbidden',
        retryable: false,
      );
    }

    if (code == 'P0002') {
      return NetworkFailure(
        message.isEmpty ? 'Conversation was not found.' : message,
        code: 'messaging_not_found',
        retryable: false,
      );
    }

    if (code == '23514') {
      return ValidationFailure(
        message.isEmpty ? 'Check the message and try again.' : message,
        code: 'messaging_validation_failed',
      );
    }

    if (code == '23505' || lowerMessage.contains('client message id')) {
      return const ValidationFailure(
        'This message retry key was already used.',
        code: 'message_idempotency_conflict',
      );
    }

    return NetworkFailure(fallbackMessage, code: code);
  }
}
