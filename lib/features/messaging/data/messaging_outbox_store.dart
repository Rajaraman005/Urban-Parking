import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

class MessagingOutboxEntry {
  const MessagingOutboxEntry({
    required this.clientMessageId,
    required this.conversationId,
    required this.body,
    required this.createdAt,
    this.lastError,
    this.retryCount = 0,
  });

  final String clientMessageId;
  final String conversationId;
  final String body;
  final DateTime createdAt;
  final String? lastError;
  final int retryCount;

  String get key => '$conversationId:$clientMessageId';

  Map<String, Object?> toJson() => {
    'clientMessageId': clientMessageId,
    'conversationId': conversationId,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'lastError': lastError,
    'retryCount': retryCount,
  };

  static MessagingOutboxEntry fromJson(Object? json) {
    final map = Map<String, Object?>.from(json as Map);
    return MessagingOutboxEntry(
      clientMessageId: map['clientMessageId']?.toString() ?? '',
      conversationId: map['conversationId']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      lastError: map['lastError']?.toString(),
      retryCount: (map['retryCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class MessagingOutboxStore {
  static const boxName = 'messaging_outbox_v1';

  Future<void> upsert(MessagingOutboxEntry entry) async {
    final box = await _box();
    await box.put(entry.key, jsonEncode(entry.toJson()));
  }

  Future<void> remove({
    required String conversationId,
    required String clientMessageId,
  }) async {
    final box = await _box();
    await box.delete('$conversationId:$clientMessageId');
  }

  Future<List<MessagingOutboxEntry>> entriesFor(String conversationId) async {
    final box = await _box();
    final entries = <MessagingOutboxEntry>[];
    for (final value in box.values) {
      try {
        final entry = MessagingOutboxEntry.fromJson(jsonDecode(value));
        if (entry.conversationId == conversationId) entries.add(entry);
      } catch (_) {
        // Ignore corrupt local outbox entries; server state remains canonical.
      }
    }
    entries.sort((left, right) => left.createdAt.compareTo(right.createdAt));
    return entries;
  }

  Future<Box<String>> _box() async {
    if (Hive.isBoxOpen(boxName)) return Hive.box<String>(boxName);
    return Hive.openBox<String>(boxName);
  }
}
