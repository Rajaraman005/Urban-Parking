import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../domain/host_parking_draft.dart';

class HostParkingLocalStore {
  HostParkingLocalStore({String boxName = _defaultBoxName})
    : _boxName = boxName;

  final String _boxName;
  Box<String>? _box;

  Future<Box<String>> _open() async {
    final existing = _box;
    if (existing != null && existing.isOpen) return existing;
    final box = await Hive.openBox<String>(_boxName);
    _box = box;
    return box;
  }

  Future<void> saveDraft(HostParkingDraft draft) async {
    final box = await _open();
    await box.put(_draftKey(draft.id), jsonEncode(draft.toJson()));
    await box.put(_latestDraftKey, draft.id);
  }

  Future<HostParkingDraft?> readDraft(String draftId) async {
    final box = await _open();
    final raw = box.get(_draftKey(draftId));
    if (raw == null) return null;
    return HostParkingDraft.fromJson(jsonDecode(raw));
  }

  Future<HostParkingDraft?> readLatestDraft() async {
    final box = await _open();
    final draftId = box.get(_latestDraftKey);
    if (draftId == null || draftId.trim().isEmpty) return null;
    return readDraft(draftId);
  }

  Future<void> enqueueMutation(
    String draftId,
    Map<String, Object?> mutation,
  ) async {
    final box = await _open();
    final key = _queueKey(draftId);
    final raw = box.get(key);
    final queue = raw == null
        ? <Object?>[]
        : List<Object?>.from(jsonDecode(raw) as List);
    queue.add(mutation);
    await box.put(key, jsonEncode(queue));
  }

  Future<List<Map<String, Object?>>> readQueuedMutations(String draftId) async {
    final box = await _open();
    final raw = box.get(_queueKey(draftId));
    if (raw == null) return const [];
    return (jsonDecode(raw) as List<dynamic>)
        .whereType<Map>()
        .map((entry) => Map<String, Object?>.from(entry))
        .toList(growable: false);
  }

  Future<void> replaceQueuedMutations(
    String draftId,
    List<Map<String, Object?>> mutations,
  ) async {
    final box = await _open();
    await box.put(_queueKey(draftId), jsonEncode(mutations));
  }

  Future<void> clearDraft(String draftId) async {
    final box = await _open();
    await box.delete(_draftKey(draftId));
    await box.delete(_queueKey(draftId));
    if (box.get(_latestDraftKey) == draftId) {
      await box.delete(_latestDraftKey);
    }
  }
}

const _defaultBoxName = 'host_parking_drafts_v2';
const _latestDraftKey = 'latest_draft_id';

String _draftKey(String draftId) => 'draft:$draftId';
String _queueKey(String draftId) => 'queue:$draftId';
