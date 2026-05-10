enum MessagingConversationType {
  property,
  support,
  system;

  static MessagingConversationType fromJson(Object? value) {
    return MessagingConversationType.values.firstWhere(
      (entry) => entry.name == value?.toString(),
      orElse: () => MessagingConversationType.property,
    );
  }
}

enum MessagingMessageType {
  text,
  attachment,
  propertyCard;

  String get apiValue => switch (this) {
    MessagingMessageType.text => 'text',
    MessagingMessageType.attachment => 'attachment',
    MessagingMessageType.propertyCard => 'property_card',
  };

  static MessagingMessageType fromJson(Object? value) {
    return switch (value?.toString()) {
      'attachment' => MessagingMessageType.attachment,
      'property_card' => MessagingMessageType.propertyCard,
      _ => MessagingMessageType.text,
    };
  }
}

enum MessagingAttachmentStatus {
  reserved,
  uploaded,
  scanning,
  available,
  rejected,
  scanFailedRetryable,
  expired;

  static MessagingAttachmentStatus fromJson(Object? value) {
    return switch (value?.toString()) {
      'uploaded' => MessagingAttachmentStatus.uploaded,
      'scanning' => MessagingAttachmentStatus.scanning,
      'available' => MessagingAttachmentStatus.available,
      'rejected' => MessagingAttachmentStatus.rejected,
      'scan_failed_retryable' => MessagingAttachmentStatus.scanFailedRetryable,
      'expired' => MessagingAttachmentStatus.expired,
      _ => MessagingAttachmentStatus.reserved,
    };
  }
}

enum LocalMessageStatus { pending, sent, failed }

class MessagingConversation {
  const MessagingConversation({
    required this.id,
    required this.type,
    required this.status,
    required this.unreadCount,
    required this.updatedAt,
    this.archivedAt,
    this.deletedAfter,
    this.lastMessageAt,
    this.lastMessageId,
    this.lastMessagePreview,
    this.lastReadMessageSeq = 0,
    this.otherAvatarUrl,
    this.otherLastSeenAt,
    this.otherName,
    this.otherPresenceStatus,
    this.otherUserId,
    this.participantRole,
    this.propertyAddress,
    this.propertyId,
    this.propertyImageUrl,
    this.propertyLocality,
    this.propertyTitle,
  });

  final String id;
  final MessagingConversationType type;
  final String status;
  final String? propertyId;
  final String? propertyTitle;
  final String? propertyAddress;
  final String? propertyLocality;
  final String? propertyImageUrl;
  final String? lastMessageId;
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final int lastReadMessageSeq;
  final String? participantRole;
  final DateTime? archivedAt;
  final DateTime? deletedAfter;
  final String? otherUserId;
  final String? otherName;
  final String? otherAvatarUrl;
  final String? otherPresenceStatus;
  final DateTime? otherLastSeenAt;
  final int unreadCount;
  final DateTime updatedAt;

  String get displayTitle {
    final name = otherName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Lotzi member';
  }

  String get propertyLabel {
    final title = propertyTitle?.trim();
    if (title != null && title.isNotEmpty) return title;
    return 'Property conversation';
  }

  String get preview {
    final value = lastMessagePreview?.trim();
    if (value != null && value.isNotEmpty) return value;
    return 'Start the conversation';
  }

  static MessagingConversation fromJson(Object? json) {
    final map = Map<String, Object?>.from(json as Map);
    return MessagingConversation(
      id: _stringFrom(map, const ['id']) ?? '',
      type: MessagingConversationType.fromJson(
        _stringFrom(map, const ['conversationType', 'conversation_type']),
      ),
      status: _stringFrom(map, const ['status']) ?? 'active',
      propertyId: _stringFrom(map, const ['propertyId', 'property_id']),
      propertyTitle: _stringFrom(map, const [
        'propertyTitle',
        'property_title',
      ]),
      propertyAddress: _stringFrom(map, const [
        'propertyAddress',
        'property_address',
      ]),
      propertyLocality: _stringFrom(map, const [
        'propertyLocality',
        'property_locality',
      ]),
      propertyImageUrl: _stringFrom(map, const [
        'propertyImageUrl',
        'property_image_url',
      ]),
      lastMessageId: _stringFrom(map, const [
        'lastMessageId',
        'last_message_id',
      ]),
      lastMessageAt: _dateTimeFrom(map, const [
        'lastMessageAt',
        'last_message_at',
      ]),
      lastMessagePreview: _stringFrom(map, const [
        'lastMessagePreview',
        'last_message_preview',
      ]),
      lastReadMessageSeq: _intFrom(map, const [
        'lastReadMessageSeq',
        'last_read_message_seq',
      ]),
      participantRole: _stringFrom(map, const [
        'participantRole',
        'participant_role',
      ]),
      archivedAt: _dateTimeFrom(map, const ['archivedAt', 'archived_at']),
      deletedAfter: _dateTimeFrom(map, const ['deletedAfter', 'deleted_after']),
      otherUserId: _stringFrom(map, const ['otherUserId', 'other_user_id']),
      otherName: _stringFrom(map, const ['otherName', 'other_name']),
      otherAvatarUrl: _stringFrom(map, const [
        'otherAvatarUrl',
        'other_avatar_url',
      ]),
      otherPresenceStatus: _stringFrom(map, const [
        'otherPresenceStatus',
        'other_presence_status',
      ]),
      otherLastSeenAt: _dateTimeFrom(map, const [
        'otherLastSeenAt',
        'other_last_seen_at',
      ]),
      unreadCount: _intFrom(map, const ['unreadCount', 'unread_count']),
      updatedAt:
          _dateTimeFrom(map, const ['updatedAt', 'updated_at']) ??
          DateTime.now(),
    );
  }
}

class MessagingMessage {
  const MessagingMessage({
    required this.id,
    required this.conversationId,
    required this.messageSeq,
    required this.senderId,
    required this.clientMessageId,
    required this.messageType,
    required this.isMine,
    required this.readByOther,
    required this.createdAt,
    this.attachments = const [],
    this.body,
    this.deletedAt,
    this.localStatus = LocalMessageStatus.sent,
    this.metadata = const {},
    this.updatedAt,
  });

  final String id;
  final String conversationId;
  final int messageSeq;
  final String senderId;
  final String clientMessageId;
  final MessagingMessageType messageType;
  final String? body;
  final Map<String, Object?> metadata;
  final bool isMine;
  final bool readByOther;
  final List<MessagingAttachment> attachments;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;
  final LocalMessageStatus localStatus;

  MessagingMessage copyWith({
    LocalMessageStatus? localStatus,
    String? id,
    int? messageSeq,
    bool? readByOther,
  }) {
    return MessagingMessage(
      id: id ?? this.id,
      conversationId: conversationId,
      messageSeq: messageSeq ?? this.messageSeq,
      senderId: senderId,
      clientMessageId: clientMessageId,
      messageType: messageType,
      body: body,
      metadata: metadata,
      isMine: isMine,
      readByOther: readByOther ?? this.readByOther,
      attachments: attachments,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      localStatus: localStatus ?? this.localStatus,
    );
  }

  static MessagingMessage pendingText({
    required String body,
    required String clientMessageId,
    required String conversationId,
    required String senderId,
  }) {
    return MessagingMessage(
      id: clientMessageId,
      conversationId: conversationId,
      messageSeq: 0,
      senderId: senderId,
      clientMessageId: clientMessageId,
      messageType: MessagingMessageType.text,
      body: body,
      isMine: true,
      readByOther: false,
      createdAt: DateTime.now(),
      localStatus: LocalMessageStatus.pending,
    );
  }

  static MessagingMessage fromJson(Object? json) {
    final map = Map<String, Object?>.from(json as Map);
    final attachments = map['attachments'];
    return MessagingMessage(
      id: _stringFrom(map, const ['id']) ?? '',
      conversationId:
          _stringFrom(map, const ['conversationId', 'conversation_id']) ?? '',
      messageSeq: _intFrom(map, const ['messageSeq', 'message_seq']),
      senderId: _stringFrom(map, const ['senderId', 'sender_id']) ?? '',
      clientMessageId:
          _stringFrom(map, const ['clientMessageId', 'client_message_id']) ??
          '',
      messageType: MessagingMessageType.fromJson(
        _stringFrom(map, const ['messageType', 'message_type']),
      ),
      body: _stringFrom(map, const ['body']),
      metadata: _mapFrom(map['metadata']),
      isMine: _boolFrom(map, const ['isMine', 'is_mine']),
      readByOther: _boolFrom(map, const ['readByOther', 'read_by_other']),
      attachments: attachments is List
          ? attachments
                .map(MessagingAttachment.fromJson)
                .toList(growable: false)
          : const [],
      createdAt:
          _dateTimeFrom(map, const ['createdAt', 'created_at']) ??
          DateTime.now(),
      updatedAt: _dateTimeFrom(map, const ['updatedAt', 'updated_at']),
      deletedAt: _dateTimeFrom(map, const ['deletedAt', 'deleted_at']),
    );
  }
}

class MessagingAttachment {
  const MessagingAttachment({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.byteSize,
    required this.status,
    this.height,
    this.storageBucket,
    this.storagePath,
    this.width,
  });

  final String id;
  final String fileName;
  final String mimeType;
  final int byteSize;
  final int? width;
  final int? height;
  final String? storageBucket;
  final String? storagePath;
  final MessagingAttachmentStatus status;

  static MessagingAttachment fromJson(Object? json) {
    final map = Map<String, Object?>.from(json as Map);
    return MessagingAttachment(
      id: _stringFrom(map, const ['id']) ?? '',
      fileName:
          _stringFrom(map, const ['fileName', 'file_name']) ?? 'Attachment',
      mimeType:
          _stringFrom(map, const ['mimeType', 'mime_type']) ??
          'application/octet-stream',
      byteSize: _intFrom(map, const ['byteSize', 'byte_size']),
      width: _nullableIntFrom(map, const ['width']),
      height: _nullableIntFrom(map, const ['height']),
      storageBucket: _stringFrom(map, const [
        'storageBucket',
        'storage_bucket',
      ]),
      storagePath: _stringFrom(map, const ['storagePath', 'storage_path']),
      status: MessagingAttachmentStatus.fromJson(
        _stringFrom(map, const ['status']),
      ),
    );
  }
}

class SendMessageRequest {
  const SendMessageRequest({
    required this.body,
    required this.clientMessageId,
    this.messageType = MessagingMessageType.text,
    this.metadata = const {},
  });

  final String body;
  final String clientMessageId;
  final MessagingMessageType messageType;
  final Map<String, Object?> metadata;

  Map<String, Object?> toJson() => {
    'body': body,
    'clientMessageId': clientMessageId,
    'messageType': messageType.apiValue,
    'metadata': metadata,
  };
}

String? _stringFrom(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}

int _intFrom(Map<String, Object?> map, List<String> keys) {
  return _nullableIntFrom(map, keys) ?? 0;
}

int? _nullableIntFrom(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
  }
  return null;
}

bool _boolFrom(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
  }
  return false;
}

DateTime? _dateTimeFrom(Map<String, Object?> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is DateTime) return value;
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return null;
}

Map<String, Object?> _mapFrom(Object? value) {
  if (value is Map) return Map<String, Object?>.from(value);
  return const {};
}
