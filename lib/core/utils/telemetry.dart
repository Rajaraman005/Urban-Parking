import 'app_logger.dart';

enum TelemetryEvent {
  appBootStarted('app_boot_started'),
  appBootCompleted('app_boot_completed'),
  authSessionHydrated('auth_session_hydrated'),
  authError('auth_error'),
  setupStepSaved('setup_step_saved'),
  cloudinaryUploadStarted('cloudinary_upload_started'),
  cloudinaryUploadCompleted('cloudinary_upload_completed'),
  cloudinaryUploadFailed('cloudinary_upload_failed'),
  geoPermissionRequested('geo_permission_requested'),
  geoPermissionDenied('geo_permission_denied'),
  geoLocationAccessChecked('geo_location_access_checked'),
  geoLocationAttemptStarted('geo_location_attempt_started'),
  geoLocationResolved('geo_location_resolved'),
  geoLocationUnavailable('geo_location_unavailable'),
  geoSearchBlockedNoLocation('geo_search_blocked_no_location'),
  geoSearchRequested('geo_search_requested'),
  geoBatchSearchRequested('geo_batch_search_requested'),
  geoCacheHit('geo_cache_hit'),
  geoCacheStaleServed('geo_cache_stale_served'),
  geoRateLimited('geo_rate_limited'),
  geoRetryCooldownTriggered('geo_retry_cooldown_triggered'),
  geoDeploymentMisconfiguration('deployment_misconfiguration'),
  geoSearchSucceeded('geo_search_succeeded'),
  geoSearchFailed('geo_search_failed'),
  geoCursorInvalidated('geo_cursor_invalidated'),
  geoResultsRendered('geo_results_rendered'),
  hostLaunchTapped('host_launch_tap'),
  hostLaunchRouteVisible('host_launch_route_visible'),
  hostLaunchFirstFrame('host_launch_first_frame'),
  hostLaunchHydrationStarted('host_launch_hydration_started'),
  hostLaunchResumeAvailable('host_launch_resume_available'),
  hostLaunchDraftReady('host_launch_draft_ready'),
  hostLaunchFailed('host_launch_failed');

  const TelemetryEvent(this.name);
  final String name;
}

class Telemetry {
  void event(TelemetryEvent event, [Map<String, Object?>? payload]) {
    appLogger.info(event.name, _sanitize(payload));
  }

  void warn(TelemetryEvent event, [Map<String, Object?>? payload]) {
    appLogger.warn(event.name, _sanitize(payload));
  }

  void error(TelemetryEvent event, [Map<String, Object?>? payload]) {
    appLogger.error(event.name, _sanitize(payload));
  }

  Map<String, Object?>? _sanitize(Map<String, Object?>? payload) {
    if (payload == null) return null;
    final clean = Map<String, Object?>.from(payload);
    clean.remove('latitude');
    clean.remove('longitude');
    return clean;
  }
}

final telemetry = Telemetry();
