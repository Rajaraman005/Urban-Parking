import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../../config/app_config.dart';
import '../../../config/geo_discovery_config.dart';
import 'geo_types.dart';

enum CacheFreshness { fresh, stale, miss }

class CacheLookup<T> {
  const CacheLookup({required this.freshness, this.value});

  final CacheFreshness freshness;
  final T? value;
}

class _CacheEntry<T> {
  const _CacheEntry({
    required this.createdAt,
    required this.sizeBytes,
    required this.value,
  });

  final DateTime createdAt;
  final int sizeBytes;
  final T value;
}

class GeoDiscoveryCache {
  final _memory =
      <String, _CacheEntry<GeoDiscoveryBatchResult<Map<String, Object?>>>>{};
  int _memoryBytes = 0;

  Box<String>? get _box => Hive.isBoxOpen(AppConfig.geoCacheBoxName)
      ? Hive.box<String>(AppConfig.geoCacheBoxName)
      : null;

  CacheLookup<GeoDiscoveryBatchResult<Map<String, Object?>>> get(String key) {
    final memory = _memory[key];
    if (memory != null) {
      _touch(key, memory);
      return _freshnessFor(memory.createdAt, memory.value, () {
        _deleteMemory(key);
      });
    }

    final encoded = _box?.get(key);
    if (encoded == null) {
      return const CacheLookup(freshness: CacheFreshness.miss);
    }

    try {
      final decoded = jsonDecode(encoded) as Map<String, Object?>;
      final createdAt = DateTime.parse(decoded['createdAt'].toString());
      final value = GeoDiscoveryBatchResult.fromJson<Map<String, Object?>>(
        Map<String, Object?>.from(decoded['value'] as Map),
        (json) => Map<String, Object?>.from(json as Map),
      );
      _setMemory(key, value);
      return _freshnessFor(createdAt, value, () {
        _box?.delete(key);
      });
    } catch (_) {
      _box?.delete(key);
      return const CacheLookup(freshness: CacheFreshness.miss);
    }
  }

  Future<void> set(
    String key,
    GeoDiscoveryBatchResult<Map<String, Object?>> value,
  ) async {
    _setMemory(key, value);

    final encodedValue = jsonEncode(value.toJson((entity) => entity));
    final encoded = jsonEncode({
      'createdAt': DateTime.now().toIso8601String(),
      'sizeBytes': encodedValue.length * 2,
      'value': jsonDecode(encodedValue),
    });
    await _box?.put(key, encoded);
    await _evictPersistentIfNeeded();
  }

  Future<void> clear() async {
    _memory.clear();
    _memoryBytes = 0;
    await _box?.clear();
  }

  CacheLookup<T> _freshnessFor<T>(
    DateTime createdAt,
    T value,
    void Function() expire,
  ) {
    final age = DateTime.now().difference(createdAt);
    if (age <= GeoDiscoveryConfig.freshTtl) {
      return CacheLookup(freshness: CacheFreshness.fresh, value: value);
    }
    if (age <= GeoDiscoveryConfig.staleTtl) {
      return CacheLookup(freshness: CacheFreshness.stale, value: value);
    }
    expire();
    return const CacheLookup(freshness: CacheFreshness.miss);
  }

  void _setMemory(
    String key,
    GeoDiscoveryBatchResult<Map<String, Object?>> value,
  ) {
    _deleteMemory(key);
    final sizeBytes = jsonEncode(value.toJson((entity) => entity)).length * 2;
    _memory[key] = _CacheEntry(
      createdAt: DateTime.now(),
      sizeBytes: sizeBytes,
      value: value,
    );
    _memoryBytes += sizeBytes;
    _evictMemoryIfNeeded();
  }

  void _touch(
    String key,
    _CacheEntry<GeoDiscoveryBatchResult<Map<String, Object?>>> entry,
  ) {
    _memory
      ..remove(key)
      ..[key] = entry;
  }

  void _deleteMemory(String key) {
    final removed = _memory.remove(key);
    if (removed != null) {
      _memoryBytes -= removed.sizeBytes;
    }
  }

  void _evictMemoryIfNeeded() {
    while (_memory.length > GeoDiscoveryConfig.memoryMaxEntries ||
        _memoryBytes > GeoDiscoveryConfig.memoryMaxBytes) {
      final oldest = _memory.keys.firstOrNull;
      if (oldest == null) break;
      _deleteMemory(oldest);
    }
  }

  Future<void> _evictPersistentIfNeeded() async {
    final box = _box;
    if (box == null) return;

    var estimatedBytes = box.values.fold<int>(
      0,
      (sum, value) => sum + value.length * 2,
    );
    while (box.length > GeoDiscoveryConfig.persistentMaxEntries ||
        estimatedBytes > GeoDiscoveryConfig.persistentMaxBytes) {
      final key = box.keys.firstOrNull;
      if (key == null) break;
      final value = box.get(key)?.length ?? 0;
      await box.delete(key);
      estimatedBytes -= value * 2;
    }
  }
}
