import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ScreenCaptureGuard {
  ScreenCaptureGuard._();

  static const _channel = MethodChannel(
    'com.urbanparking.india/screen_capture_guard',
  );

  static int _activeLocks = 0;

  static Future<void> acquire() async {
    if (!_supportsSecureFlag) return;
    _activeLocks += 1;
    if (_activeLocks > 1) return;
    await _setSecureEnabled(true);
  }

  static Future<void> release() async {
    if (!_supportsSecureFlag || _activeLocks == 0) return;
    _activeLocks -= 1;
    if (_activeLocks > 0) return;
    await _setSecureEnabled(false);
  }

  static Future<void> refresh() async {
    if (!_supportsSecureFlag || _activeLocks == 0) return;
    await _setSecureEnabled(true);
  }

  static bool get _supportsSecureFlag => !kIsWeb && Platform.isAndroid;

  static Future<void> _setSecureEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setSecureEnabled', {
        'enabled': enabled,
      });
    } on MissingPluginException {
      // Keep viewer usable on unsupported platforms and test hosts.
    } on PlatformException {
      // Best-effort protection should not crash the viewer experience.
    }
  }
}
